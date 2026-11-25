import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/premium/data/datasources/premium_device_info.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../support/fake_begzar_backend.dart';
import '../../../../support/memory_keyed_storage.dart';

/// A device name that does not need the platform channel.
class _NamedDevice extends PremiumDeviceInfo {
  @override
  Future<String> getDeviceName() async => 'Test phone';
}

/// A data source whose engine operations [backend] answers, on storage
/// seeded with [storage] and an install id of `install-id`.
PremiumRemoteDataSource _engineRemote(
  FakeBegzarBackend backend, {
  Map<String, String> storage = const {},
  Future<Either<ApiFailure, String>> Function()? ensureSessionToken,
}) {
  AppSecureStorage.debugInstance = MemoryKeyedStorage({...storage});
  addTearDown(() => AppSecureStorage.debugInstance = null);
  return PremiumRemoteDataSource(
    backend: backend,
    deviceInfo: _NamedDevice(),
    ensureSessionToken: ensureSessionToken,
    deviceIdentity: DeviceIdentity(
      storage: MemoryKeyedStorage({'premium_device_id': 'install-id'}),
    ),
  );
}

const _session = BackendSession(
  accessKey: 'key',
  account: BackendAccount(username: 'reader@example.com'),
);

const _refusedOutright = BackendException(
  BackendFailureKind.unexpected,
  message: 'refused without words',
);

void main() {
  group('PremiumRemoteDataSource.login', () {
    test('should read a session with no expiry as never subscribed', () async {
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumSignIn:
              (username, password, deviceName, credentials) async =>
                  const BackendAnswer(
                    BackendSession(
                      accessKey: 'key',
                      account: BackendAccount(username: 'reader@example.com'),
                    ),
                  ),
        ),
      );

      final result = await remote.login(
        username: 'reader@example.com',
        password: 'secret-password',
        deviceId: 'device',
      );

      final session = result.getOrElse((failure) => fail('$failure'));
      expect(session.accessKey, 'key');
      expect(session.account.neverSubscribed, isTrue);
    });

    test(
      'should hand the engine the trimmed name, the device and its name',
      () async {
        late List<Object> asked;
        final remote = _engineRemote(
          FakeBegzarBackend(
            onPremiumSignIn:
                (username, password, deviceName, credentials) async {
                  asked = [
                    username,
                    password,
                    deviceName,
                    credentials.deviceId,
                    credentials.accessKey,
                    credentials.sessionKey,
                  ];
                  return const BackendAnswer(
                    BackendSession(
                      accessKey: 'key',
                      account: BackendAccount(username: 'user'),
                    ),
                  );
                },
          ),
          storage: {ApiV2Service.keySessionToken: 'session-key'},
        );

        await remote.login(
          username: ' user ',
          password: ' secret ',
          deviceId: 'device',
        );

        expect(asked, [
          'user',
          ' secret ',
          'Test phone',
          'device',
          '',
          'session-key',
        ]);
      },
    );

    test('should name a refusal the engine named', () async {
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumSignIn:
              (username, password, deviceName, credentials) async =>
                  throw const BackendException(
                    BackendFailureKind.server,
                    message: 'Invalid username or password',
                    status: 401,
                    refusal: BackendRefusal.invalidCredentials,
                  ),
        ),
      );

      final result = await remote.login(
        username: 'user',
        password: 'wrong',
        deviceId: 'device',
      );

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.invalidCredentials,
      );
    });

    test('should name an unexpected answer after signing in', () async {
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumSignIn:
              (username, password, deviceName, credentials) async =>
                  throw const BackendException(BackendFailureKind.unexpected),
        ),
      );

      final result = await remote.login(
        username: 'user',
        password: 'secret',
        deviceId: 'device',
      );

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.loginFailed,
      );
    });
  });

  group('PremiumRemoteDataSource.fetchUserData', () {
    test('should read the account and its devices, newest first', () async {
      late BackendPremiumCredentials asked;
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumAccount: (credentials) async {
            asked = credentials;
            return const BackendAnswer(
              BackendAccountData(
                account: BackendAccount(
                  username: 'reader',
                  email: 'reader@example.com',
                ),
                rosterKnown: true,
                devices: [
                  BackendDevice(deviceId: 'old', loggedInAt: '2026-01-01'),
                  BackendDevice(deviceId: ''),
                  BackendDevice(deviceId: 'new', loggedInAt: '2026-06-01'),
                ],
              ),
            );
          },
        ),
      );

      final result = await remote.fetchUserData('key');

      final userData = result.getOrElse((failure) => fail('$failure'));
      expect(userData.account.username, 'reader');
      expect(userData.account.email, 'reader@example.com');
      expect(userData.account.neverSubscribed, isTrue);
      expect(userData.devices.devices.map((d) => d.deviceId), ['new', 'old']);
      expect(userData.devices.devices.first.deviceName, 'Unknown Device');
      expect(userData.devices.maxDevices, 2);
      expect(userData.devices.rosterKnown, isTrue);
      expect([asked.accessKey, asked.deviceId], ['key', 'install-id']);
    });

    test(
      'should keep a roster that was not sent apart from an empty one',
      () async {
        final remote = _engineRemote(
          FakeBegzarBackend(
            onPremiumAccount: (_) async => const BackendAnswer(
              BackendAccountData(
                account: BackendAccount(username: 'reader'),
                rosterKnown: false,
              ),
            ),
          ),
        );

        final result = await remote.fetchUserData('key');

        expect(
          result.getOrElse((failure) => fail('$failure')).devices.rosterKnown,
          isFalse,
        );
      },
    );
  });

  group('PremiumRemoteDataSource.fetchServers', () {
    test('should keep only the configs the tunnel can dial', () async {
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumServers: (_) async => const BackendAnswer([
            BackendPremiumServer(
              id: 1,
              configs: [
                BackendPremiumConfig(
                  id: 10,
                  url: 'vless://a@example.invalid:443',
                ),
                BackendPremiumConfig(id: 11, url: 'not a link'),
              ],
            ),
            BackendPremiumServer(
              id: 2,
              configs: [BackendPremiumConfig(id: 20, url: '')],
            ),
          ]),
        ),
      );

      final servers = (await remote.fetchServers(
        'key',
      )).getOrElse((failure) => fail('$failure'));

      expect(servers.map((s) => s.id), [1]);
      expect(servers.single.name, 'Server');
      expect(servers.single.configs.map((c) => c.id), [10]);
    });
  });

  group('PremiumRemoteDataSource.removeDevice', () {
    test('should free the named device under this install', () async {
      late List<String> asked;
      final remote = _engineRemote(
        FakeBegzarBackend(
          onPremiumRemoveDevice: (deviceId, credentials) async {
            asked = [deviceId, credentials.accessKey, credentials.deviceId];
            return const BackendAnswer(1);
          },
        ),
      );

      final result = await remote.removeDevice(
        accessKey: 'key',
        deviceId: 'other',
      );

      expect(result.getOrElse((failure) => fail('$failure')), 1);
      expect(asked, ['other', 'key', 'install-id']);
    });
  });

  group('PremiumRemoteDataSource.signUp', () {
    test(
      'should hand the engine the email, the password and the session',
      () async {
        late List<String> asked;
        final remote = _engineRemote(
          FakeBegzarBackend(
            onRequestSignUpCode: (email, password, credentials) async {
              asked = [
                email,
                password,
                credentials.sessionKey,
                credentials.accessKey,
              ];
              return const BackendAnswer(30);
            },
          ),
          storage: {ApiV2Service.keySessionToken: 'session-key'},
        );

        await remote.signUp(email: 'reader@example.com', password: 'secret');

        expect(asked, ['reader@example.com', 'secret', 'session-key', '']);
      },
    );

    test('should read the wait as the cooldown', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onRequestSignUpCode: (_, _, _) async => const BackendAnswer(90),
        ),
      ).signUp(email: 'reader@example.com', password: 'secret');

      expect(result.getRight().toNullable(), const Duration(seconds: 90));
    });

    for (final wait in [null, 0, -5]) {
      test('should fall back to 60 seconds for a wait of $wait', () async {
        final result = await _engineRemote(
          FakeBegzarBackend(
            onRequestSignUpCode: (_, _, _) async => BackendAnswer(wait),
          ),
        ).signUp(email: 'reader@example.com', password: 'secret');

        expect(result.getRight().toNullable(), const Duration(seconds: 60));
      });
    }

    test('should name a taken email as the reason', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onRequestSignUpCode: (_, _, _) async => throw const BackendException(
            BackendFailureKind.server,
            message: 'email_taken',
            status: 422,
            refusal: BackendRefusal.emailTaken,
          ),
        ),
      ).signUp(email: 'reader@example.com', password: 'secret');

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.emailTaken,
      );
    });

    test('should name a wordless refusal after the call', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onRequestSignUpCode: (_, _, _) async => throw _refusedOutright,
        ),
      ).signUp(email: 'reader@example.com', password: 'secret');

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.signUpFailed,
      );
    });
  });

  group('PremiumRemoteDataSource device session', () {
    test('should register the session before asking for a code', () async {
      late FakeBegzarBackend backend;
      var askedBeforeSession = -1;
      backend = FakeBegzarBackend(
        onRequestSignUpCode: (_, _, _) async => const BackendAnswer(30),
      );
      final remote = _engineRemote(
        backend,
        ensureSessionToken: () async {
          askedBeforeSession = backend.calls.length;
          return right('session-key');
        },
      );

      await remote.signUp(email: 'reader@example.com', password: 'secret');

      expect(askedBeforeSession, 0);
      expect(backend.calls, ['requestSignUpCode']);
    });

    test('should register the session before resending a code', () async {
      late FakeBegzarBackend backend;
      var askedBeforeSession = -1;
      backend = FakeBegzarBackend(
        onResendSignUpCode: (_, _) async => const BackendAnswer(30),
      );
      final remote = _engineRemote(
        backend,
        ensureSessionToken: () async {
          askedBeforeSession = backend.calls.length;
          return right('session-key');
        },
      );

      await remote.resendSignUpCode(email: 'reader@example.com');

      expect(askedBeforeSession, 0);
      expect(backend.calls, ['resendSignUpCode']);
    });

    test('should not ask for a code without a session', () async {
      final backend = FakeBegzarBackend(
        onRequestSignUpCode: (_, _, _) async => const BackendAnswer(30),
      );
      final result = await _engineRemote(
        backend,
        ensureSessionToken: () async => left(
          const UnexpectedFailure(
            'no session',
            userFacingKey: UserFacingErrorKeys.deviceInitFailed,
          ),
        ),
      ).signUp(email: 'reader@example.com', password: 'secret');

      expect(backend.calls, isEmpty);
      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.deviceInitFailed,
      );
    });
  });

  group('PremiumRemoteDataSource.resendSignUpCode', () {
    test('should hand the engine only the email', () async {
      late String asked;
      await _engineRemote(
        FakeBegzarBackend(
          onResendSignUpCode: (email, _) async {
            asked = email;
            return const BackendAnswer(30);
          },
        ),
      ).resendSignUpCode(email: 'reader@example.com');

      expect(asked, 'reader@example.com');
    });
  });

  group('PremiumRemoteDataSource.verifySignUp', () {
    test('should send the device and its name with the code', () async {
      late List<String> asked;
      await _engineRemote(
        FakeBegzarBackend(
          onConfirmSignUp: (email, code, deviceName, credentials) async {
            asked = [email, code, deviceName, credentials.deviceId];
            return const BackendAnswer(_session);
          },
        ),
      ).verifySignUp(
        email: 'reader@example.com',
        code: '123456',
        deviceId: 'device',
      );

      expect(asked, ['reader@example.com', '123456', 'Test phone', 'device']);
    });

    test('should return the session the answer describes', () async {
      final result =
          await _engineRemote(
            FakeBegzarBackend(
              onConfirmSignUp: (_, _, _, _) async =>
                  const BackendAnswer(_session),
            ),
          ).verifySignUp(
            email: 'reader@example.com',
            code: '123456',
            deviceId: 'd',
          );

      final session = result.getOrElse((failure) => fail('$failure'));
      expect(session.accessKey, 'key');
      expect(session.account.username, 'reader@example.com');
    });

    test('should name a wrong code and an answer without a session', () async {
      final wrong = await _engineRemote(
        FakeBegzarBackend(
          onConfirmSignUp: (_, _, _, _) async => throw const BackendException(
            BackendFailureKind.server,
            message: 'invalid_code',
            status: 422,
            refusal: BackendRefusal.codeInvalid,
          ),
        ),
      ).verifySignUp(email: 'reader@example.com', code: '1', deviceId: 'd');
      expect(
        wrong.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.codeInvalid,
      );

      final sessionless = await _engineRemote(
        FakeBegzarBackend(
          onConfirmSignUp: (_, _, _, _) async => throw _refusedOutright,
        ),
      ).verifySignUp(email: 'reader@example.com', code: '1', deviceId: 'd');
      expect(
        sessionless.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.verifyFailed,
      );
    });
  });

  group('PremiumRemoteDataSource.deleteAccount', () {
    test('should send the access key, device and password', () async {
      late List<String> asked;
      final result = await _engineRemote(
        FakeBegzarBackend(
          onDeleteAccount: (password, credentials) async {
            asked = [password, credentials.accessKey, credentials.deviceId];
            return const BackendAnswer(null);
          },
        ),
      ).deleteAccount(accessKey: 'key', deviceId: 'device', password: 'pw');

      expect(result.isRight(), isTrue);
      expect(asked, ['pw', 'key', 'device']);
    });

    test('should name a wrong password', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onDeleteAccount: (_, _) async => throw const BackendException(
            BackendFailureKind.server,
            message: 'invalid_password',
            status: 422,
            refusal: BackendRefusal.wrongPassword,
          ),
        ),
      ).deleteAccount(accessKey: 'key', deviceId: 'device', password: 'pw');

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.wrongPassword,
      );
    });

    test('should name a wordless refusal after the call', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onDeleteAccount: (_, _) async => throw _refusedOutright,
        ),
      ).deleteAccount(accessKey: 'key', deviceId: 'device', password: 'pw');

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.deleteAccountFailed,
      );
    });
  });

  group('PremiumRemoteDataSource.fetchPlans', () {
    test('should read the plans in order', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(
          onPremiumPlans: () async => const BackendAnswer([
            BackendPlan(devices: 1, productId: 'one', basePlanId: 'monthly'),
            BackendPlan(devices: 2, productId: 'two', basePlanId: 'yearly'),
          ]),
        ),
      ).fetchPlans();

      final plans = result.getOrElse((failure) => fail('$failure'));
      expect(plans.map((plan) => plan.productId), ['one', 'two']);
      expect(plans.last.devices, 2);
      expect(plans.last.basePlanId, 'yearly');
    });

    test('should name a refused catalogue as unavailable plans', () async {
      final result = await _engineRemote(
        FakeBegzarBackend(onPremiumPlans: () async => throw _refusedOutright),
      ).fetchPlans();

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.plansUnavailable,
      );
    });
  });

  group('PremiumRemoteDataSource.reportGooglePlayPurchase', () {
    test('should send the purchase with the access key and device', () async {
      late List<String> asked;
      final result =
          await _engineRemote(
            FakeBegzarBackend(
              onReportPlayPurchase: (productId, token, credentials) async {
                asked = [
                  productId,
                  token,
                  credentials.accessKey,
                  credentials.deviceId,
                ];
                return const BackendAnswer(null);
              },
            ),
          ).reportGooglePlayPurchase(
            accessKey: 'key',
            deviceId: 'device',
            productId: 'premium_3_device',
            purchaseToken: 'token',
          );

      expect(result.isRight(), isTrue);
      expect(asked, ['premium_3_device', 'token', 'key', 'device']);
    });

    test('should name a refused report as a failed purchase', () async {
      final result =
          await _engineRemote(
            FakeBegzarBackend(
              onReportPlayPurchase: (_, _, _) async => throw _refusedOutright,
            ),
          ).reportGooglePlayPurchase(
            accessKey: 'key',
            deviceId: 'device',
            productId: 'premium_3_device',
            purchaseToken: 'token',
          );

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.purchaseFailed,
      );
    });

    test('should keep the status of a refusal for the Play rule', () async {
      final result =
          await _engineRemote(
            FakeBegzarBackend(
              onReportPlayPurchase: (_, _, _) async =>
                  throw const BackendException(
                    BackendFailureKind.server,
                    message: 'invalid_purchase',
                    status: 422,
                    serverMessage: 'invalid_purchase',
                  ),
            ),
          ).reportGooglePlayPurchase(
            accessKey: 'key',
            deviceId: 'device',
            productId: 'premium_3_device',
            purchaseToken: 'token',
          );

      expect(
        result.getLeft().toNullable(),
        isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 422),
      );
    });
  });
}
