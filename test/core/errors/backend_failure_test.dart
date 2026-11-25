import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/backend_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a refusal the engine named', () {
    test('should be shown as its own message, whatever the text says', () {
      for (final refusal in BackendRefusal.values) {
        final failure = ServerFailure(
          'Network unreachable',
          statusCode: 403,
          serverError: 'something else entirely',
          refusal: refusal,
        );
        expect(
          failure.userFacingKey,
          userFacingKeyForRefusal(refusal),
          reason: refusal.name,
        );
      }
    });

    test('should name a different message for each refusal', () {
      final keys = BackendRefusal.values.map(userFacingKeyForRefusal).toSet();
      expect(keys, hasLength(BackendRefusal.values.length));
    });

    test('should still read as a rate limit on a 429', () {
      const failure = ServerFailure(
        'Too many attempts. Please try again later',
        statusCode: 429,
        refusal: BackendRefusal.ipBlocked,
      );
      expect(failure.userFacingKey, UserFacingErrorKeys.rateLimit);
    });

    test('should leave the status and the text to decide without one', () {
      const failure = ServerFailure('Forbidden', statusCode: 403);
      expect(failure.userFacingKey, UserFacingErrorKeys.forbidden);
    });

    test('should read no backend words as a refusal of its own', () {
      // The engine names refusals; the app no longer knows the backend's
      // phrasing for them, so the same words without a refusal are prose.
      const failure = ServerFailure(
        'Invalid signature',
        statusCode: 400,
        serverError: 'Invalid signature',
      );
      expect(
        failure.userFacingKey,
        isNot(UserFacingErrorKeys.requestUnverified),
      );
    });

    test('should fall back to the generic patterns in its message', () {
      expect(
        serverFailureKey(statusCode: 500, message: 'request timed out'),
        UserFacingErrorKeys.connectionTimeout,
      );
      expect(
        serverFailureKey(statusCode: 500),
        UserFacingErrorKeys.connectionFailed,
      );
      expect(
        serverFailureKey(statusCode: 401, message: 'anything'),
        UserFacingErrorKeys.unauthorized,
      );
    });
  });

  group('apiFailureFromBackend', () {
    ApiFailure from(BackendException e) => apiFailureFromBackend(
      e,
      unexpectedKey: UserFacingErrorKeys.loginFailed,
    );

    test('should rebuild each failure the engine named', () {
      expect(
        from(const BackendException(BackendFailureKind.network)),
        isA<NetworkFailure>(),
      );
      expect(
        from(const BackendException(BackendFailureKind.timeout)),
        isA<TimeoutFailure>(),
      );
      expect(
        from(const BackendException(BackendFailureKind.pinning)),
        isA<PinningFailure>(),
      );
      expect(
        from(const BackendException(BackendFailureKind.payload)),
        isA<PayloadFailure>(),
      );
      expect(
        from(const BackendException(BackendFailureKind.noConfigs)),
        isA<NoConfigsFailure>(),
      );
    });

    test('should carry a refusal field for field', () {
      final failure = from(
        const BackendException(
          BackendFailureKind.server,
          message: 'Device limit reached (3/3)',
          status: 403,
          serverMessage: 'Device limit reached (3/3)',
          refusal: BackendRefusal.deviceLimit,
        ),
      );
      expect(
        failure,
        isA<ServerFailure>()
            .having((f) => f.statusCode, 'statusCode', 403)
            .having(
              (f) => f.serverError,
              'serverError',
              'Device limit reached (3/3)',
            )
            .having((f) => f.refusal, 'refusal', BackendRefusal.deviceLimit),
      );
      expect(failure.userFacingKey, UserFacingErrorKeys.deviceLimit);
    });

    test('should keep the wait a rate limit asked for', () {
      final failure = from(
        const BackendException(
          BackendFailureKind.rateLimit,
          message: 'slow down',
          retryAfterSeconds: 42,
        ),
      );
      expect(
        failure,
        isA<RateLimitFailure>().having(
          (f) => f.retryAfterSeconds,
          'retryAfterSeconds',
          42,
        ),
      );
    });

    test('should show an unexpected answer as the call that was made', () {
      final failure = from(
        const BackendException(BackendFailureKind.unexpected),
      );
      expect(failure.userFacingKey, UserFacingErrorKeys.loginFailed);
    });

    test('should say the engine is missing, not that there is no network', () {
      final failure = from(
        const BackendException(BackendFailureKind.engineMissing),
      );
      expect(failure, isA<EngineMissingFailure>());
      expect(failure.userFacingKey, UserFacingErrorKeys.engineMissing);
    });
  });
}
