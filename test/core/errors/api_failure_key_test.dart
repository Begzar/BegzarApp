import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('an API failure names its own key', () {
    // The keys these variants answer used to come out of a regex over
    // [ApiFailure.message], which is developer-facing log text. Pinning them
    // here is what makes rewording a log line a test failure rather than a
    // silent change to the sentence a user reads.
    test('the key does not depend on the message', () {
      const cases = <ApiFailure, String>{
        NetworkFailure(): UserFacingErrorKeys.networkError,
        TimeoutFailure(): UserFacingErrorKeys.connectionTimeout,
        PinningFailure(): UserFacingErrorKeys.secureConnectionFailed,
        RateLimitFailure('slow down'): UserFacingErrorKeys.rateLimit,
        SessionFailure('no session'): UserFacingErrorKeys.sessionNotFound,
        PayloadFailure('bad envelope'): UserFacingErrorKeys.fetchConfigsFailed,
        NoConfigsFailure('nothing'): UserFacingErrorKeys.noConfigsFromServer,
      };

      cases.forEach((failure, expectedKey) {
        expect(failure.userFacingKey, expectedKey, reason: '$failure');
      });
    });

    test('rewording a message cannot move the key', () {
      // 'premium session' used to route SessionFailure to errAccessDenied and
      // 'decrypt' used to route PayloadFailure to errNoWorkingConfig, purely
      // because those words appear in the log text.
      const worded = SessionFailure('Premium session not found.');
      const plain = SessionFailure('');
      expect(worded.userFacingKey, plain.userFacingKey);

      const decrypting = PayloadFailure('Failed to decrypt subscription');
      const silent = PayloadFailure('');
      expect(decrypting.userFacingKey, silent.userFacingKey);
    });

    test('every variant answers a key the UI can translate', () {
      const failures = <ApiFailure>[
        NetworkFailure(),
        TimeoutFailure(),
        PinningFailure(),
        RateLimitFailure('429'),
        SessionFailure('gone'),
        ServerFailure('boom', statusCode: 500),
        PayloadFailure('undecodable'),
        NoConfigsFailure('empty'),
        UnexpectedFailure(
          'anything',
          userFacingKey: UserFacingErrorKeys.loginFailed,
        ),
      ];

      for (final failure in failures) {
        expect(
          isUserFacingErrorKey(failure.userFacingKey),
          isTrue,
          reason: '$failure answers ${failure.userFacingKey}, '
              'which reaches the UI as raw text',
        );
      }
    });

    // The catch-all cannot know what it caught, only which call was being
    // made, so the call site names the key and the type makes that mandatory.
    test('the catch-all carries the key its call site chose', () {
      const failure = UnexpectedFailure(
        'Failed to remove device: TypeError',
        userFacingKey: UserFacingErrorKeys.removeDevice,
        cause: 'TypeError',
      );

      expect(failure.userFacingKey, UserFacingErrorKeys.removeDevice);
      expect(failure.cause, 'TypeError');
    });
  });
}
