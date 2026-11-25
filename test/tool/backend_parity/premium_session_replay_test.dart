import 'package:begzar/modules/premium/data/datasources/premium_device_info.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_replay.dart';

// None of these is a real key or device.
const _accessKey = 'YWNjZXNzLWtleS1mb3ItcGFyaXR5LXRlc3RzLTAwMDE=';
const _device = 'device-for-parity-tests';

class _NamedDevice extends PremiumDeviceInfo {
  @override
  Future<String> getDeviceName() async => 'Parity Device';
}

Object? _describeUserData(PremiumUserData data) => {
  'username': data.account.username,
  'email': data.account.email,
  'expireDate': data.account.expireDate,
  'statusLabel': data.account.statusLabel,
  'maxDevices': data.devices.maxDevices,
  'activeDevices': data.devices.activeDevices,
  'rosterKnown': data.devices.rosterKnown,
  'devices': [
    for (final d in data.devices.devices)
      {
        'deviceId': d.deviceId,
        'deviceName': d.deviceName,
        'loggedInAt': d.loggedInAt?.toIso8601String(),
      },
  ],
};

void main() {
  final replay = BackendReplay.load('premium_session');

  PremiumRemoteDataSource remote(BegzarBackend backend) =>
      PremiumRemoteDataSource(backend: backend, deviceInfo: _NamedDevice());

  test('the premium session reaches every outcome it reached before the engine '
      'took its calls over', () async {
    for (final c in replay!.cases) {
      final name = c['name']! as String;
      switch (c['op']) {
        case 'premiumSignIn':
          final escapes = name.contains('escapes');
          await replay.check(
            c,
            call: (backend) => remote(backend).login(
              username: escapes ? 'ünïcode<&>' : ' parity-user ',
              password: escapes ? 'q"\\\n\t\u0001\u2028/é😀' : 'p@ss word',
              deviceId: _device,
            ),
            describe: (session) => escapes
                ? {'accessKey': session.accessKey}
                : {
                    'accessKey': session.accessKey,
                    'username': session.account.username,
                    'email': session.account.email,
                    'expireDate': session.account.expireDate,
                    'statusLabel': session.account.statusLabel,
                  },
          );
        case 'premiumAccount':
          await replay.check(
            c,
            call: (backend) => remote(backend).fetchUserData(_accessKey),
            describe: _describeUserData,
          );
        case 'premiumSignOut':
          await replay.check(
            c,
            call: (backend) => remote(
              backend,
            ).logout(accessKey: _accessKey, deviceId: _device),
            describe: (_) => {'done': true},
          );
        case 'premiumRemoveDevice':
          await replay.check(
            c,
            call: (backend) => remote(
              backend,
            ).removeDevice(accessKey: _accessKey, deviceId: 'another-device'),
            describe: (active) => {'activeDevices': active},
          );
        case 'premiumServers':
          await replay.check(
            c,
            call: (backend) => remote(backend).fetchServers(_accessKey),
            describe: (servers) => [
              for (final s in servers)
                {
                  'id': s.id,
                  'name': s.name,
                  'icon': s.icon,
                  'configs': [
                    for (final config in s.configs)
                      {'id': config.id, 'name': config.name, 'url': config.url},
                  ],
                },
            ],
          );
        default:
          fail('no call replays ${c['op']}');
      }
    }
  }, skip: replay == null ? 'the private engine is not checked out' : false);
}
