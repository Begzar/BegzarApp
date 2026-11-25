import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/premium/application/services/premium_account_service.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/sign_up.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/sign_up_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' hide State;

/// Creating an account: the details, then the emailed code.
///
/// Hands the finished account to [PremiumNotifier] rather than holding it,
/// so a sign-up ends exactly where a sign-in does. The hand-over runs one way
/// only; the premium controller never reads this one.
class SignUpNotifier extends Notifier<SignUpState> {
  static const _log = Log('premium');

  late PremiumAccountService _accounts;

  @override
  SignUpState build() {
    _accounts = ref.watch(premiumAccountServiceProvider);
    return const SignUpState();
  }

  DateTime _resendFrom(Duration wait) => DateTime.now().add(wait);

  void _logRefusal(String event, ApiFailure failure) {
    _log.warn(event, {
      'reason': failure.runtimeType,
      'key': failure.userFacingKey,
    });
  }

  /// Runs one step against the server, turning a throw — storage that will
  /// not answer, most likely — into a failure named [failedKey], so the form
  /// is never left waiting on an answer that is not coming.
  Future<Either<ApiFailure, T>> _attempt<T>(
    Future<Either<ApiFailure, T>> Function() step,
    String failedKey,
  ) async {
    try {
      return await step();
    } catch (error) {
      _log.error('signup.threw', {'type': error.runtimeType}, error);
      return left(
        UnexpectedFailure(
          'Sign-up step threw',
          userFacingKey: failedKey,
          cause: error,
        ),
      );
    }
  }

  /// Checks the form, then asks for a code. A tap that lands while the first
  /// one is still waiting for the server is dropped rather than sent again.
  Future<void> submitDetails({
    required String email,
    required String password,
    required String confirmation,
  }) async {
    if (state.isSubmitting) return;

    final SignUpDetails details;
    switch (SignUpDetails.parse(
      email: email,
      password: password,
      confirmation: confirmation,
    )) {
      case Left(value: final problem):
        state = state.copyWith(fieldError: problem, clearError: true);
        return;
      case Right(value: final parsed):
        details = parsed;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFieldError: true,
      clearError: true,
    );
    _log.trace('signup.submit');
    final result = await _attempt(
      () => _accounts.signUp(details),
      UserFacingErrorKeys.signUpFailed,
    );
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        _logRefusal('signup.submit.refused', failure);
        state = state.copyWith(
          isSubmitting: false,
          errorKey: failure.userFacingKey,
        );
      case Right(value: final wait):
        state = SignUpState(
          step: SignUpStep.code,
          email: details.email,
          resendAvailableAt: _resendFrom(wait),
        );
    }
  }

  Future<void> resendCode() async {
    final email = state.email;
    if (email == null || state.isSubmitting) return;

    state = state.copyWith(
      isSubmitting: true,
      clearFieldError: true,
      clearError: true,
    );
    _log.trace('signup.resend');
    final result = await _attempt(
      () => _accounts.resendSignUpCode(email),
      UserFacingErrorKeys.signUpFailed,
    );
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        _logRefusal('signup.resend.refused', failure);
        state = state.copyWith(
          isSubmitting: false,
          errorKey: failure.userFacingKey,
        );
      case Right(value: final wait):
        state = state.copyWith(
          isSubmitting: false,
          resendAvailableAt: _resendFrom(wait),
        );
    }
  }

  /// Confirms the code, which signs the user in.
  Future<void> verify(String code) async {
    final email = state.email;
    if (email == null || state.isSubmitting) return;

    final normalized = ConfirmationCode.normalize(code);
    if (normalized == null) {
      state = state.copyWith(
        fieldError: SignUpFieldError.codeFormat,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearFieldError: true,
      clearError: true,
    );
    _log.trace('signup.verify');
    final result = await _attempt(
      () => _accounts.verifySignUp(email: email, code: normalized),
      UserFacingErrorKeys.verifyFailed,
    );
    if (!ref.mounted) return;

    switch (result) {
      case Left(value: final failure):
        _logRefusal('signup.verify.refused', failure);
        state = state.copyWith(
          isSubmitting: false,
          errorKey: failure.userFacingKey,
        );
      case Right(value: final session):
        // Reset before handing over: signing in takes the form off screen,
        // and this provider goes with it.
        state = const SignUpState();
        ref
            .read(premiumProvider.notifier)
            .adoptSignedUpAccount(session.account);
    }
  }

  /// Back to the details, to send the code somewhere else.
  void editEmail() {
    state = const SignUpState();
  }
}

/// Auto-disposed, so leaving the sign-up form starts it over next time.
final signUpProvider =
    NotifierProvider.autoDispose<SignUpNotifier, SignUpState>(
      SignUpNotifier.new,
    );
