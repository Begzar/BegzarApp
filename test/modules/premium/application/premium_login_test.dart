import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';

import '../../../support/memory_keyed_storage.dart';

class _StubPremiumRemoteDataSource extends PremiumRemoteDataSource {
  _StubPremiumRemoteDataSource({required this.session});

  final PremiumSession session;

  @override
  Future<Either<ApiFailure, PremiumSession>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    return Right(session);
  }

  @override
  Future<Either<ApiFailure, PremiumUserData>> fetchUserData(
    String accessKey,
  ) async {
    return Right(
      PremiumUserData(
        account: session.account,
        devices: const LinkedDevices(
          maxDevices: 1,
          activeDevices: 1,
          devices: [
            PremiumDevice(deviceId: testDeviceId, deviceName: 'This phone'),
          ],
        ),
      ),
    );
  }
}

/// Far enough out that the subscription cannot lapse while the suite runs.
String _activeExpiry() =>
    DateTime.now().add(const Duration(days: 30)).toIso8601String();

String _lapsedExpiry() =>
    DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

/// Builds the provider and lets its session restore finish.
///
/// `PremiumNotifier.build` starts a restore without awaiting it, so a test
/// that logs in immediately races that restore and its state write can land
/// after the container is torn down.
Future<ProviderContainer> _containerFor(PremiumSession session) async {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(storageWithDeviceId()),
      premiumRemoteDataSourceProvider.overrideWithValue(
        _StubPremiumRemoteDataSource(session: session),
      ),
    ],
  );
  addTearDown(container.dispose);

  for (
    var i = 0;
    i < 20 && container.read(premiumProvider) is PremiumRestoring;
    i++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(
    container.read(premiumProvider),
    isNot(isA<PremiumRestoring>()),
    reason: 'session restore did not settle',
  );

  return container;
}

PremiumSession _session({required String expireDate, String? statusLabel}) {
  return PremiumSession(
    accessKey: 'access-key',
    account: PremiumAccount(
      username: 'user',
      expireDate: expireDate,
      statusLabel: statusLabel,
    ),
  );
}

void main() {
  test('login with an active subscription is entitled', () async {
    final container = await _containerFor(
      _session(expireDate: _activeExpiry(), statusLabel: 'true'),
    );

    await container.read(premiumProvider.notifier).login('user', 'password');

    final state = container.read(premiumProvider);
    expect(state, isA<PremiumSignedIn>());
    expect(state.isEntitled, isTrue);
  });

  test(
    'login with a lapsed subscription signs in without entitlement',
    () async {
      final container = await _containerFor(
        _session(expireDate: _lapsedExpiry(), statusLabel: 'true'),
      );

      await container.read(premiumProvider.notifier).login('user', 'password');

      final state = container.read(premiumProvider);
      expect(state, isA<PremiumSignedIn>());
      expect(state.isEntitled, isFalse);
      expect(state.hasActiveSubscription, isFalse);
    },
  );

  test('login with a disabled account signs in without entitlement', () async {
    final container = await _containerFor(
      _session(expireDate: _activeExpiry(), statusLabel: 'disabled'),
    );

    await container.read(premiumProvider.notifier).login('user', 'password');

    final state = container.read(premiumProvider);
    expect(state, isA<PremiumSignedIn>());
    expect(state.isEntitled, isFalse);
    expect(state.hasActiveSubscription, isTrue);
  });

  test('a restored session is entitled without an interactive login', () async {
    final session = _session(expireDate: _activeExpiry(), statusLabel: 'true');
    final storage = storageWithDeviceId();

    final first = ProviderContainer(
      overrides: [
        flutterSecureStorageProvider.overrideWithValue(storage),
        premiumRemoteDataSourceProvider.overrideWithValue(
          _StubPremiumRemoteDataSource(session: session),
        ),
      ],
    );
    await first.read(premiumProvider.notifier).login('user', 'password');
    first.dispose();

    final second = ProviderContainer(
      overrides: [
        flutterSecureStorageProvider.overrideWithValue(storage),
        premiumRemoteDataSourceProvider.overrideWithValue(
          _StubPremiumRemoteDataSource(session: session),
        ),
      ],
    );
    addTearDown(second.dispose);
    for (
      var i = 0;
      i < 20 && second.read(premiumProvider) is PremiumRestoring;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }

    final state = second.read(premiumProvider);
    expect(state, isA<PremiumSignedIn>());
    expect(state.isEntitled, isTrue);
    expect(state.username, 'user');
  });
}
