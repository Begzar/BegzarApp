import 'dart:io';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/data/repositories/app_version_repository.dart';
import 'package:begzar/modules/premium/data/datasources/premium_device_info.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';
import 'package:fpdart/fpdart.dart';

import '../../../tool/fake_backend/fake_premium_backend.dart';

const _email = 'reader@example.com';
const _password = 'correct horse';
const _deviceId = 'this-device';

/// A device name that does not need the platform channel.
class _NamedDevice extends PremiumDeviceInfo {
  @override
  Future<String> getDeviceName() async => 'Test phone';
}

PremiumRemoteDataSource _remote() => PremiumRemoteDataSource(
  backend: FakePremiumBackend(),
  deviceInfo: _NamedDevice(),
);

/// Signs up and confirms with the fixed code, answering with the access key.
Future<String> _signUp(PremiumRemoteDataSource remote) async {
  await remote.signUp(email: _email, password: _password);
  final verified = await remote.verifySignUp(
    email: _email,
    code: FakePremiumBackend.confirmationCode,
    deviceId: _deviceId,
  );
  return verified.getOrElse((failure) => fail('$failure')).accessKey;
}

Future<Either<ApiFailure, Unit>> _reportToken(
  PremiumRemoteDataSource remote,
  String accessKey,
  String purchaseToken,
) => remote.reportGooglePlayPurchase(
  accessKey: accessKey,
  deviceId: _deviceId,
  productId: 'premium_1_device',
  purchaseToken: purchaseToken,
);

/// Reports the first purchase of [basePlanId] the fake Play would make.
Future<void> _report(
  PremiumRemoteDataSource remote,
  String accessKey,
  String basePlanId,
) async {
  final reported = await _reportToken(
    remote,
    accessKey,
    FakePremiumBackend.purchaseTokenFor(basePlanId, 1),
  );
  expect(reported.isRight(), isTrue);
}

Future<PremiumAccount> _accountOf(
  PremiumRemoteDataSource remote,
  String accessKey,
) async {
  final userData = await remote.fetchUserData(accessKey);
  return userData.getOrElse((failure) => fail('$failure')).account;
}

int _daysUntil(DateTime moment) => moment.difference(DateTime.now()).inDays;

void main() {
  // The data source reads the session key and the install id from storage.
  setUp(() => AppSecureStorage.debugInstance = MemoryKeyedStorage());
  tearDown(() => AppSecureStorage.debugInstance = null);

  group('FakePremiumBackend', () {
    // The real catalog does not name a latest release yet, so this answer is
    // what puts the update row and the dot on a device.
    test(
      'should offer a newer release on every channel without forcing one',
      () async {
        final catalog = await AppVersionRepository(
          backend: FakePremiumBackend(),
        ).fetch();

        for (final source in AppDistributionSource.values) {
          final release = catalog?.lookup(
            AppDistribution.catalogPlatform,
            source.apiKey,
          );
          expect(
            release?.version,
            FakePremiumBackend.minimumVersion,
            reason: source.apiKey,
          );
          expect(
            release?.latestVersion,
            FakePremiumBackend.latestVersion,
            reason: source.apiKey,
          );
          expect(
            release?.url,
            FakePremiumBackend.updatePage,
            reason: source.apiKey,
          );
        }
      },
    );

    test('should sign up, confirm with the fixed code and answer user-data for '
        'the new key', () async {
      final remote = _remote();

      final accessKey = await _signUp(remote);
      final userData = await remote.fetchUserData(accessKey);

      final account = userData.getOrElse((failure) => fail('$failure'));
      expect(account.account.username, _email);
      expect(account.account.neverSubscribed, isTrue);
      expect(account.devices.registers(_deviceId), isTrue);
    });

    // Removing a device needs a device other than this one to remove.
    test('should list a second device that can be removed', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      await remote.removeDevice(
        accessKey: accessKey,
        deviceId: FakePremiumBackend.otherDeviceId,
      );
      final userData = await remote.fetchUserData(accessKey);

      final devices = userData.getOrElse((failure) => fail('$failure')).devices;
      expect(devices.registers(FakePremiumBackend.otherDeviceId), isFalse);
      expect(devices.registers(_deviceId), isTrue);
    });

    test('should refuse a second sign-up with the same email', () async {
      final remote = _remote();
      await _signUp(remote);

      final second = await remote.signUp(email: _email, password: _password);

      expect(
        second.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.emailTaken,
      );
    });

    test('should forget an account once it is deleted', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      await remote.deleteAccount(
        accessKey: accessKey,
        deviceId: _deviceId,
        password: _password,
      );
      final login = await remote.login(
        username: _email,
        password: _password,
        deviceId: _deviceId,
      );

      expect(login.isLeft(), isTrue);
    });

    test('should list every device count for every period', () async {
      final plans = await _remote().fetchPlans();

      final listed = plans.getOrElse((failure) => fail('$failure'));
      expect(listed, hasLength(20));
      expect(listed.map((plan) => plan.devices).toSet(), {1, 2, 3, 4, 5});
    });

    // The real Play prices only the ids Play Console holds, and those follow
    // no single pattern: these are the ones that break it.
    test('should list the plans under the ids Play Console holds', () async {
      final plans = await _remote().fetchPlans();

      final listed = plans.getOrElse((failure) => fail('$failure'));
      final byBasePlan = {for (final plan in listed) plan.basePlanId: plan};
      for (final plan in listed) {
        expect(plan.productId, 'premium_${plan.devices}_device');
      }
      expect(byBasePlan['premium-3-device-quarterly-new']?.devices, 3);
      expect(byBasePlan['premium-3-device-semiannual-new']?.devices, 3);
      expect(byBasePlan['premium-5-devices-monthly']?.devices, 5);
      expect(byBasePlan, isNot(contains('premium-3-device-quarterly')));
      expect(byBasePlan, isNot(contains('premium-3-device-semiannual')));
    });

    test('should grant the months a reported purchase bought', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      await _report(remote, accessKey, 'premium-1-device-quarterly');

      final account = await _accountOf(remote, accessKey);
      expect(account.isEntitled, isTrue);
      expect(_daysUntil(account.expiresAt!), inInclusiveRange(88, 93));
    });

    test('should grant a purchase reported twice once', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      await _report(remote, accessKey, 'premium-1-device-monthly');
      await _report(remote, accessKey, 'premium-1-device-monthly');

      final account = await _accountOf(remote, accessKey);
      expect(_daysUntil(account.expiresAt!), inInclusiveRange(27, 32));
    });

    // A token from the real Play carries nothing this backend can read, and
    // the app reports no base plan beside it.
    test('should grant one month for a purchase the real Play made', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      final reported = await _reportToken(remote, accessKey, 'token-from-play');

      expect(reported.isRight(), isTrue);
      final account = await _accountOf(remote, accessKey);
      expect(_daysUntil(account.expiresAt!), inInclusiveRange(27, 32));
    });

    test('should refuse its own purchase of a plan it does not sell', () async {
      final remote = _remote();
      final accessKey = await _signUp(remote);

      final reported = await _reportToken(
        remote,
        accessKey,
        FakePremiumBackend.purchaseTokenFor('premium-1-device-weekly', 1),
      );

      expect(
        reported.getLeft().toNullable(),
        isA<ServerFailure>().having(
          (failure) => failure.statusCode,
          'statusCode',
          HttpStatus.unprocessableEntity,
        ),
      );
    });
  });
}
