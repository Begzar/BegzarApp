import 'dart:async';
import 'dart:convert';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/memory_keyed_storage.dart';

/// One response answers both halves of the premium screen, so two callers
/// arriving together must not turn it back into two requests.
void main() {
  test('two callers at once share one request', () async {
    final remote = _CountingRemote();
    final repository = _repository(remote);

    final both = Future.wait([
      repository.refreshAccount(),
      repository.refreshAccount(),
    ]);
    await remote.answer();
    final results = await both;

    expect(remote.calls, 1);
    expect(results.first?.isRight(), isTrue);
    expect(results.last?.isRight(), isTrue);
  });

  // Sharing is not caching. Entitlement is the server's to decide, so a caller
  // that arrives after the last answer landed must ask again.
  test('the next caller after one settles asks again', () async {
    final remote = _CountingRemote();
    final repository = _repository(remote);

    final first = repository.refreshAccount();
    await remote.answer();
    await first;

    final second = repository.refreshAccount();
    await remote.answer();
    await second;

    expect(remote.calls, 2);
  });

  test('a failed refresh does not wedge the next one', () async {
    final remote = _CountingRemote();
    final repository = _repository(remote);

    final first = repository.refreshAccount();
    await remote.fail(StateError('network gone'));
    await expectLater(first, throwsStateError);

    final second = repository.refreshAccount();
    await remote.answer();

    expect((await second)?.isRight(), isTrue);
    expect(remote.calls, 2);
  });

  /// A seat removed on another device is how a session ends without this one
  /// being told, so the roster that rides along with every refresh is what
  /// says the stored session is spent.
  group('a roster that no longer registers this device', () {
    test('should end the stored session', () async {
      final store = _seededStore();
      final repository = _repository(
        _StaticRemote(_roster(['someone-else'])),
        store,
      );

      final result = await repository.refreshAccount();

      expect(result?.isLeft(), isTrue);
      expect(await repository.readSession(), isNull);
      expect(store.values.containsKey('premium_session_v1'), isFalse);
    });

    test('should fail with the device-removed key', () async {
      final repository = _repository(
        _StaticRemote(_roster(['someone-else'])),
        _seededStore(),
      );

      final result = await repository.refreshAccount();

      expect(
        result?.getLeft().toNullable(),
        isA<SessionRevokedFailure>().having(
          (failure) => failure.userFacingKey,
          'userFacingKey',
          UserFacingErrorKeys.deviceRemoved,
        ),
      );
    });

    test('should end the session when the roster is empty', () async {
      final repository = _repository(
        _StaticRemote(_roster(const [])),
        _seededStore(),
      );

      final result = await repository.refreshAccount();

      expect(result?.isLeft(), isTrue);
      expect(await repository.readSession(), isNull);
    });
  });

  test(
    'should keep the session when the roster still lists this device',
    () async {
      final repository = _repository(
        _StaticRemote(_roster([_deviceId, 'someone-else'])),
        _seededStore(),
      );

      final result = await repository.refreshAccount();

      expect(result?.isRight(), isTrue);
      expect(await repository.readSession(), isNotNull);
    },
  );

  // Absence is not removal. A response that carried no roster at all says
  // nothing about this device, and signing out on it would empty the app of
  // every premium user the moment the server stopped sending the list.
  test('should keep the session when no roster was sent', () async {
    final repository = _repository(
      _StaticRemote(
        const LinkedDevices(
          maxDevices: 2,
          activeDevices: 2,
          devices: <PremiumDevice>[],
          rosterKnown: false,
        ),
      ),
      _seededStore(),
    );

    final result = await repository.refreshAccount();

    expect(result?.isRight(), isTrue);
    expect(await repository.readSession(), isNotNull);
  });

  group('PremiumRepository sign-up and deletion', () {
    test('should store the session a confirmed sign-up returns', () async {
      final store = MemoryKeyedStorage();
      final repository = _repository(
        _AccountRemote(verifyResult: right(_signedUpSession)),
        store,
      );

      await repository.verifySignUp(
        email: 'reader@example.com',
        code: '123456',
      );

      expect(
        (await repository.readSession())?.account.username,
        'reader@example.com',
      );
    });

    test('should store nothing when the code is refused', () async {
      final store = MemoryKeyedStorage();
      final repository = _repository(
        _AccountRemote(
          verifyResult: left(
            const ServerFailure(
              'invalid_code',
              serverError: 'invalid_code',
              refusal: BackendRefusal.codeInvalid,
            ),
          ),
        ),
        store,
      );

      await repository.verifySignUp(
        email: 'reader@example.com',
        code: '000001',
      );

      expect(await repository.readSession(), isNull);
    });

    test('should clear the session once the account is deleted', () async {
      final repository = _repository(
        _AccountRemote(deleteResult: right(unit)),
        _seededStore(),
      );

      final result = await repository.deleteAccount('secret-password');

      expect(result.isRight(), isTrue);
      expect(await repository.readSession(), isNull);
    });

    // The account is gone on the server; a keystore that will not let go of
    // the session must not turn that into a reported failure.
    test('should report a deletion the server made even when the stored '
        'session cannot be cleared', () async {
      final repository = _repository(
        _AccountRemote(deleteResult: right(unit)),
        _UndeletableStore(_seededStore().values),
      );

      final result = await repository.deleteAccount('secret-password');

      expect(result.isRight(), isTrue);
    });

    test('should keep the session when deletion is refused', () async {
      final repository = _repository(
        _AccountRemote(
          deleteResult: left(
            const ServerFailure(
              'invalid_password',
              serverError: 'invalid_password',
              refusal: BackendRefusal.wrongPassword,
            ),
          ),
        ),
        _seededStore(),
      );

      await repository.deleteAccount('wrong-password');

      expect(await repository.readSession(), isNotNull);
    });

    test('should refuse deletion with no session', () async {
      final remote = _AccountRemote(deleteResult: right(unit));
      final repository = _repository(remote, MemoryKeyedStorage());

      final result = await repository.deleteAccount('secret-password');

      expect(
        result.getLeft().toNullable(),
        PremiumRepository.sessionMissingFailure,
      );
      expect(remote.deleteCalls, 0);
    });
  });

  group('PremiumRepository.reportGooglePlayPurchase', () {
    test('should report with the stored key and this device', () async {
      final remote = _AccountRemote();
      final repository = _repository(remote, _seededStore());

      await repository.reportGooglePlayPurchase(
        productId: 'premium_1_device',
        purchaseToken: 'token',
      );

      expect(remote.reported, [
        ('key', _deviceId, 'premium_1_device', 'token'),
      ]);
    });

    test('should refuse a purchase report with no session', () async {
      final remote = _AccountRemote();
      final repository = _repository(remote, MemoryKeyedStorage());

      final result = await repository.reportGooglePlayPurchase(
        productId: 'premium_1_device',
        purchaseToken: 'token',
      );

      expect(
        result.getLeft().toNullable(),
        PremiumRepository.sessionMissingFailure,
      );
      expect(remote.reported, isEmpty);
    });

    // A refresh sent before the grant answers with the account before it, so
    // the next caller has to ask again rather than share that answer — and
    // the stale one settling must not cut the fresh one loose either.
    test('should ask afresh once a purchase is granted mid-refresh', () async {
      final remote = _GrantingRemote();
      final repository = _repository(remote);

      final before = repository.refreshAccount();
      await repository.reportGooglePlayPurchase(
        productId: 'premium_1_device',
        purchaseToken: 'token',
      );
      final after = repository.refreshAccount();
      await pumpEventQueue();
      final askedAfresh = remote.calls;

      await remote.answer();
      await before;
      final alongside = repository.refreshAccount();
      await pumpEventQueue();
      final sharedTheFreshOne = remote.calls;
      await remote.answer();
      await Future.wait([after, alongside]);

      expect(askedAfresh, 2);
      expect(sharedTheFreshOne, 2);
    });
  });
}

/// Holds each refresh open like [_CountingRemote], and grants every purchase.
class _GrantingRemote extends _CountingRemote {
  @override
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String accessKey,
    required String deviceId,
    required String productId,
    required String purchaseToken,
  }) async => right(unit);
}

const _deviceId = 'this-device';

const _signedUpSession = PremiumSession(
  accessKey: 'new-key',
  account: PremiumAccount(username: 'reader@example.com'),
);

/// A keystore that reads and writes but will not delete anything.
class _UndeletableStore extends MemoryKeyedStorage {
  _UndeletableStore(super.seed);

  @override
  Future<void> delete({required String key}) async =>
      throw StateError('keystore locked');
}

/// Answers the sign-up and delete-account calls from a script.
class _AccountRemote extends PremiumRemoteDataSource {
  _AccountRemote({this.verifyResult, this.deleteResult});

  final Either<ApiFailure, PremiumSession>? verifyResult;
  final Either<ApiFailure, Unit>? deleteResult;
  int deleteCalls = 0;

  @override
  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
    required String deviceId,
  }) async => verifyResult!;

  @override
  Future<Either<ApiFailure, Unit>> deleteAccount({
    required String accessKey,
    required String deviceId,
    required String password,
  }) async {
    deleteCalls++;
    return deleteResult!;
  }

  /// Every purchase report, as (access key, device, product, token).
  final List<(String, String, String, String)> reported = [];

  @override
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String accessKey,
    required String deviceId,
    required String productId,
    required String purchaseToken,
  }) async {
    reported.add((accessKey, deviceId, productId, purchaseToken));
    return right(unit);
  }
}

LinkedDevices _roster(List<String> deviceIds) => LinkedDevices(
  maxDevices: 3,
  activeDevices: deviceIds.length,
  devices: [
    for (final deviceId in deviceIds)
      PremiumDevice(deviceId: deviceId, deviceName: 'Device $deviceId'),
  ],
);

MemoryKeyedStorage _seededStore() {
  final store = MemoryKeyedStorage();
  store.values['premium_device_id'] = _deviceId;
  store.values['premium_session_v1'] = jsonEncode({
    'access_key': 'key',
    'username': 'user',
    'expire_date': '2099-01-01',
  });
  return store;
}

/// Answers every refresh with the same body, so a test can say what the server
/// reported without holding the call open.
class _StaticRemote extends PremiumRemoteDataSource {
  _StaticRemote(this.devices);

  final LinkedDevices devices;

  @override
  Future<Either<ApiFailure, PremiumUserData>> fetchUserData(
    String accessKey,
  ) async => Right(
    PremiumUserData(
      account: PremiumAccount(
        username: 'user',
        expireDate: '2099-01-01',
        statusLabel: 'true',
      ),
      devices: devices,
    ),
  );
}

PremiumRepository _repository(
  PremiumRemoteDataSource remote, [
  MemoryKeyedStorage? store,
]) {
  return PremiumRepository(
    remote: remote,
    storage: PremiumStorage(storage: store ?? _seededStore()),
  );
}

/// Counts the calls and holds each one open until the test says otherwise, so
/// a second caller is guaranteed to arrive while the first is still running.
class _CountingRemote extends PremiumRemoteDataSource {
  int calls = 0;
  final List<Completer<Either<ApiFailure, PremiumUserData>>> _pending = [];

  /// Waits for the call to actually reach here — a refresh reads storage
  /// first, so it is not in flight the moment it is started.
  Future<void> _untilCalled() async {
    for (var attempt = 0; attempt < 100 && _pending.isEmpty; attempt++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> answer() async {
    await _untilCalled();
    _pending
        .removeAt(0)
        .complete(
          Right(
            PremiumUserData(
              account: PremiumAccount(
                username: 'user',
                expireDate: '2099-01-01',
                statusLabel: 'true',
              ),
              devices: _roster(const [_deviceId]),
            ),
          ),
        );
  }

  Future<void> fail(Object error) async {
    await _untilCalled();
    _pending.removeAt(0).completeError(error);
  }

  @override
  Future<Either<ApiFailure, PremiumUserData>> fetchUserData(String accessKey) {
    calls++;
    final completer = Completer<Either<ApiFailure, PremiumUserData>>();
    _pending.add(completer);
    return completer.future;
  }
}
