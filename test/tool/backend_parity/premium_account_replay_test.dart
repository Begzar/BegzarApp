import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/datasources/premium_device_info.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'backend_replay.dart';

// None of these is a real key, device, account or purchase.
const _session = 'c2Vzc2lvbi1rZXktZm9yLXBhcml0eS10ZXN0cy0wMDE=';
const _accessKey = 'YWNjZXNzLWtleS1mb3ItcGFyaXR5LXRlc3RzLTAwMDE=';
const _device = 'device-for-parity-tests';

class _NamedDevice extends PremiumDeviceInfo {
  @override
  Future<String> getDeviceName() async => 'Parity Device';
}

void main() {
  final replay = BackendReplay.load('premium_account');

  PremiumRemoteDataSource remote(
    BegzarBackend backend, {
    bool sessionRefused = false,
  }) => PremiumRemoteDataSource(
    backend: backend,
    deviceInfo: _NamedDevice(),
    ensureSessionToken: () async => sessionRefused
        ? left(const NetworkFailure('no session'))
        : right(_session),
  );

  Object? wait(Duration d) => {'resendAfterSeconds': d.inSeconds};
  Object? done(Object? _) => {'done': true};

  test(
    'sign-up, deletion, plans and purchases reach every outcome they reached '
    'before the engine took their calls over',
    () async {
      for (final c in replay!.cases) {
        switch (c['op']) {
          case 'requestSignUpCode':
            await replay.check(
              c,
              call: (backend) =>
                  remote(
                    backend,
                    sessionRefused: c['name'] == 'no session',
                  ).signUp(
                    email: 'parity@example.invalid',
                    password: 'p@ss <word>',
                  ),
              describe: wait,
            );
          case 'resendSignUpCode':
            await replay.check(
              c,
              call: (backend) => remote(
                backend,
              ).resendSignUpCode(email: 'parity@example.invalid'),
              describe: wait,
            );
          case 'confirmSignUp':
            await replay.check(
              c,
              call: (backend) => remote(backend).verifySignUp(
                email: 'parity@example.invalid',
                code: '123456',
                deviceId: _device,
              ),
              describe: (session) => {
                'accessKey': session.accessKey,
                'username': session.account.username,
                'email': session.account.email,
                'expireDate': session.account.expireDate,
                'statusLabel': session.account.statusLabel,
              },
            );
          case 'deleteAccount':
            await replay.check(
              c,
              call: (backend) => remote(backend).deleteAccount(
                accessKey: _accessKey,
                deviceId: _device,
                password: 'p@ss "word"',
              ),
              describe: done,
            );
          case 'premiumPlans':
            await replay.check(
              c,
              call: (backend) => remote(backend).fetchPlans(),
              describe: (plans) => [
                for (final p in plans)
                  {
                    'devices': p.devices,
                    'productId': p.productId,
                    'basePlanId': p.basePlanId,
                  },
              ],
            );
          case 'reportPlayPurchase':
            await replay.check(
              c,
              call: (backend) => remote(backend).reportGooglePlayPurchase(
                accessKey: _accessKey,
                deviceId: _device,
                productId: 'premium_3_devices',
                purchaseToken: 'token-for-parity-tests',
              ),
              describe: done,
            );
          default:
            fail('no call replays ${c['op']}');
        }
      }
    },
    skip: replay == null ? 'the private engine is not checked out' : false,
  );
}
