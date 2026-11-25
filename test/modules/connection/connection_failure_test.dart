import 'package:begzar/core/domain/errors/failure.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/connection/data/tunnel_failures.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a connection failure names its own key', () {
    test('each variant answers a key the UI can translate', () {
      const cases = <ConnectionFailure, String>{
        InvalidConfigFailure(): UserFacingErrorKeys.invalidConfig,
        ProxyTestFailure(): UserFacingErrorKeys.proxyTestFailed,
        NoWorkingConfigFailure(3, 'tried 3'):
            UserFacingErrorKeys.noWorkingConfig,
        VpnPermissionFailure(): UserFacingErrorKeys.accessDenied,
        ElevationDeclinedFailure(): UserFacingErrorKeys.elevationDeclined,
      };

      cases.forEach((failure, expectedKey) {
        expect(failure.userFacingKey, expectedKey, reason: '$failure');
        expect(
          isUserFacingErrorKey(failure.userFacingKey),
          isTrue,
          reason: 'an unknown key reaches the UI as raw text',
        );
      });
    });

    // The point of the contract: presentation reads one member and never asks
    // which family answered.
    test('both failure families are read through the same contract', () {
      const connection = ProxyTestFailure();
      const api = TimeoutFailure();

      final failures = <Failure>[connection, api];

      expect(failures.map((f) => f.userFacingKey), [
        UserFacingErrorKeys.proxyTestFailed,
        UserFacingErrorKeys.connectionTimeout,
      ]);
    });

    // Declining the admin prompt is the user's own choice, so it gets a
    // sentence of its own rather than the access-denied one, which would send
    // them to sign in again.
    test('should name the elevation key for a declined prompt', () {
      const failure = ElevationDeclinedFailure();

      expect(failure.userFacingKey, UserFacingErrorKeys.elevationDeclined);
      expect(failure.message, 'Administrator permission declined');
    });

    // A tunnel failure takes its key from the call site, so a key missing
    // from the vocabulary would be read as prose and guessed at instead.
    test('should treat the three tunnel keys as user-facing', () {
      const keys = [
        UserFacingErrorKeys.elevationDeclined,
        UserFacingErrorKeys.tunnelUnavailable,
        UserFacingErrorKeys.tunnelStopped,
      ];

      for (final key in keys) {
        expect(isUserFacingErrorKey(key), isTrue, reason: key);
      }
    });
  });

  group('wrapping a throw from the engine', () {
    // The engine reports failures as prose, so the text is read exactly once —
    // here — and everything above works from the key.
    test('resolves the engine prose to a key', () {
      final failure = tunnelFailure(
        'Connection failed',
        Exception('Failed to start VPN mode: Failed host lookup'),
      );

      expect(failure.userFacingKey, UserFacingErrorKeys.networkError);
    });

    test('an unrecognized cause still lands on a translatable key', () {
      final failure = tunnelFailure(
        'Disconnect failed',
        Exception('¯\\_(ツ)_/¯'),
      );

      expect(isUserFacingErrorKey(failure.userFacingKey), isTrue);
    });

    test('keeps the cause in the message for logs', () {
      final failure = tunnelFailure('Connection failed', 'engine said no');

      expect(failure.message, contains('engine said no'));
    });
  });
}
