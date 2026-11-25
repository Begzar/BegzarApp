import 'package:begzar/modules/connection/data/tunnel_failures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVpnPermissionRefusal', () {
    test('should recognise Android refusing the VPN consent dialog', () {
      // What BegzarEnginePlugin answers when the user cancels the system dialog.
      final refusal = PlatformException(
        code: 'VPN_PERMISSION_DENIED',
        message: 'User denied VPN permission or declined to switch VPN',
      );

      expect(isVpnPermissionRefusal(refusal), isTrue);
    });

    test('should recognise Apple refusing to install the VPN profile', () {
      expect(
        isVpnPermissionRefusal(
          Exception(
            'The operation couldn’t be completed. (NEVPNErrorDomain '
            'error 5.)',
          ),
        ),
        isTrue,
      );
    });

    test('should recognise a refused prepare', () {
      expect(isVpnPermissionRefusal(Exception('PREPARE_FAILED')), isTrue);
    });

    test('should recognise plain permission-denied prose', () {
      expect(
        isVpnPermissionRefusal(Exception('VPN permission denied')),
        isTrue,
      );
    });

    test('should not mistake an engine failure for a refusal', () {
      expect(
        isVpnPermissionRefusal(Exception('Failed to start VPN mode: exited')),
        isFalse,
      );
    });

    test('should not mistake a tunnel that never came up for a refusal', () {
      expect(
        isVpnPermissionRefusal(
          Exception('Apple VPN tunnel did not become connected in time'),
        ),
        isFalse,
      );
    });
  });
}
