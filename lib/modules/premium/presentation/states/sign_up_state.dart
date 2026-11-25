import 'package:begzar/modules/premium/domain/sign_up.dart';

/// Where in creating an account the user is: entering their details, or
/// entering the code that was emailed to them.
enum SignUpStep { details, code }

/// The sign-up form's state. A value: two states holding the same fields are
/// the same state, so republishing one is filtered out.
final class SignUpState {
  const SignUpState({
    this.step = SignUpStep.details,
    this.email,
    this.isSubmitting = false,
    this.fieldError,
    this.errorKey,
    this.resendAvailableAt,
  });

  final SignUpStep step;

  /// The address the code went to, once one has been sent.
  final String? email;

  final bool isSubmitting;

  /// A problem with one field, shown under that field.
  final SignUpFieldError? fieldError;

  /// A refusal from the server, as an l10n key, shown in a banner.
  final String? errorKey;

  /// When another code may be asked for.
  final DateTime? resendAvailableAt;

  SignUpState copyWith({
    bool? isSubmitting,
    SignUpFieldError? fieldError,
    String? errorKey,
    DateTime? resendAvailableAt,
    bool clearFieldError = false,
    bool clearError = false,
  }) {
    return SignUpState(
      step: step,
      email: email,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      fieldError: clearFieldError ? null : (fieldError ?? this.fieldError),
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SignUpState &&
      other.step == step &&
      other.email == email &&
      other.isSubmitting == isSubmitting &&
      other.fieldError == fieldError &&
      other.errorKey == errorKey &&
      other.resendAvailableAt == resendAvailableAt;

  @override
  int get hashCode => Object.hash(
    step,
    email,
    isSubmitting,
    fieldError,
    errorKey,
    resendAvailableAt,
  );
}
