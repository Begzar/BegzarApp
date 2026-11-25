import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/sign_up.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/sign_up_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/states/sign_up_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../premium_test_doubles.dart';

const _email = 'reader@example.com';
const _password = 'correct horse';

const _newAccount = PremiumAccount(username: _email);

/// A repository whose storage gives way while a confirmed sign-up is saved.
class _ThrowingVerifyRepository extends FakePremiumRepository {
  @override
  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
  }) async => throw StateError('storage unavailable');
}

/// A container whose sign-up provider stays alive between calls. It is
/// auto-disposed, and nothing on screen is listening in a test.
ProviderContainer _container(FakePremiumRepository repository) {
  final container = ProviderContainer(
    overrides: [premiumRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container.listen(signUpProvider, (_, _) {});
  return container;
}

Future<void> _submitValid(SignUpNotifier notifier) => notifier.submitDetails(
  email: '  $_email ',
  password: _password,
  confirmation: _password,
);

/// Whether [moment] lands within a second after [wait] from now.
Matcher _about(Duration wait) {
  final earliest = DateTime.now()
      .add(wait)
      .subtract(const Duration(seconds: 1));
  final latest = DateTime.now().add(wait).add(const Duration(seconds: 1));
  return predicate<DateTime?>(
    (moment) =>
        moment != null && moment.isAfter(earliest) && moment.isBefore(latest),
    'about $wait from now',
  );
}

void main() {
  group('SignUpNotifier.submitDetails', () {
    test(
      'should stop at the first field problem without asking the server',
      () async {
        final repository = FakePremiumRepository();
        final container = _container(repository);

        await container
            .read(signUpProvider.notifier)
            .submitDetails(
              email: 'nobody',
              password: _password,
              confirmation: _password,
            );

        expect(
          container.read(signUpProvider).fieldError,
          SignUpFieldError.emailInvalid,
        );
        expect(repository.signUpCount, 0);
      },
    );

    test('should move to the code step once the code is sent', () async {
      final container = _container(FakePremiumRepository());

      await _submitValid(container.read(signUpProvider.notifier));

      final state = container.read(signUpProvider);
      expect(state.step, SignUpStep.code);
      expect(state.email, _email);
      expect(state.resendAvailableAt, _about(const Duration(minutes: 1)));
    });

    test(
      'should keep the details step and name the reason when refused',
      () async {
        final repository = FakePremiumRepository(
          signUpResult: left(
            const ServerFailure(
              'email_taken',
              serverError: 'email_taken',
              refusal: BackendRefusal.emailTaken,
            ),
          ),
        );
        final container = _container(repository);

        await _submitValid(container.read(signUpProvider.notifier));

        final state = container.read(signUpProvider);
        expect(state.step, SignUpStep.details);
        expect(state.errorKey, UserFacingErrorKeys.emailTaken);
        expect(state.isSubmitting, isFalse);
      },
    );

    test('should send one request for a double tap', () async {
      final repository = FakePremiumRepository();
      final notifier = _container(repository).read(signUpProvider.notifier);

      await Future.wait([_submitValid(notifier), _submitValid(notifier)]);

      expect(repository.signUpCount, 1);
    });
  });

  group('SignUpNotifier.verify', () {
    test('should reject a malformed code without asking the server', () async {
      final repository = FakePremiumRepository();
      final container = _container(repository);
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);

      await notifier.verify('12a');

      expect(
        container.read(signUpProvider).fieldError,
        SignUpFieldError.codeFormat,
      );
      expect(repository.verifyCount, 0);
    });

    test('should sign the user in once the code is accepted', () async {
      final repository = FakePremiumRepository(
        verifyResult: right(
          const PremiumSession(accessKey: 'new-key', account: _newAccount),
        ),
      );
      final container = _container(repository);
      await container.read(premiumProvider.notifier).ensureRestored();
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);

      await notifier.verify('123 456');

      final premium = container.read(premiumProvider);
      expect(premium, isA<PremiumSignedIn>());
      expect(premium.account, _newAccount);
    });

    // Storage that will not answer throws rather than returning a failure;
    // the form must not be left spinning on it.
    test('should release the form when confirming throws', () async {
      final container = _container(_ThrowingVerifyRepository());
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);

      await notifier.verify('123456');

      final state = container.read(signUpProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.errorKey, UserFacingErrorKeys.verifyFailed);
    });

    test('should stay on the code step when the code is refused', () async {
      final container = _container(FakePremiumRepository());
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);

      await notifier.verify('000001');

      final state = container.read(signUpProvider);
      expect(state.step, SignUpStep.code);
      expect(state.errorKey, UserFacingErrorKeys.codeInvalid);
    });
  });

  group('SignUpNotifier.resendCode', () {
    test('should restart the cooldown on resend', () async {
      final repository = FakePremiumRepository(
        resendResult: right(const Duration(minutes: 2)),
      );
      final container = _container(repository);
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);

      await notifier.resendCode();

      expect(repository.resendCount, 1);
      expect(
        container.read(signUpProvider).resendAvailableAt,
        _about(const Duration(minutes: 2)),
      );
    });
  });

  group('SignUpNotifier.editEmail', () {
    test('should return to the details step to change the email', () async {
      final container = _container(FakePremiumRepository());
      final notifier = container.read(signUpProvider.notifier);
      await _submitValid(notifier);
      await notifier.verify('000001');

      notifier.editEmail();

      final state = container.read(signUpProvider);
      expect(state.step, SignUpStep.details);
      expect(state.errorKey, isNull);
      expect(state.fieldError, isNull);
    });
  });
}
