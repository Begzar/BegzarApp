import 'package:fpdart/fpdart.dart';

/// Which field of the sign-up form is wrong, so the form can say so under
/// that field rather than in a banner.
enum SignUpFieldError {
  emailInvalid,
  passwordTooShort,
  passwordMismatch,
  codeFormat,
}

/// Sign-up input that has already been checked and normalized.
///
/// These checks only answer early, before a request is spent finding out:
/// the server decides what an acceptable email or password is, and its answer
/// is final.
class SignUpDetails {
  const SignUpDetails._({required this.email, required this.password});

  /// Shorter than this is refused before it is sent.
  static const minimumPasswordLength = 8;

  /// One `@`, something on either side, and a dot in the domain. Deliberately
  /// loose: the code sent to the address is what proves it works.
  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Trimmed. A space or a newline picked up from a paste is not part of the
  /// address.
  final String email;

  /// Never trimmed — whitespace can be a deliberate part of a password.
  final String password;

  /// Checks the fields in the order the form shows them, so the problem
  /// reported is the first one the user would reach.
  static Either<SignUpFieldError, SignUpDetails> parse({
    required String email,
    required String password,
    required String confirmation,
  }) {
    final trimmedEmail = email.trim();
    if (!_emailShape.hasMatch(trimmedEmail)) {
      return left(SignUpFieldError.emailInvalid);
    }
    if (password.length < minimumPasswordLength) {
      return left(SignUpFieldError.passwordTooShort);
    }
    if (password != confirmation) {
      return left(SignUpFieldError.passwordMismatch);
    }
    return right(SignUpDetails._(email: trimmedEmail, password: password));
  }
}

/// The code emailed to confirm a new account.
abstract final class ConfirmationCode {
  static const length = 6;

  static final _digits = RegExp('^[0-9]{$length}\$');

  /// Whitespace, plus the zero-width joiner and direction marks that come
  /// along when a code is copied out of right-to-left text.
  static final _ignored = RegExp('[\\s‌‎‏]');

  static const _asciiZero = 0x30;
  static const _persianZero = 0x06F0;
  static const _arabicIndicZero = 0x0660;
  static const _digitsInBase = 10;

  /// The ASCII digit a Persian or Arabic-Indic digit stands for; anything
  /// else is returned as it is.
  static int _toAscii(int rune) {
    for (final zero in [_persianZero, _arabicIndicZero]) {
      if (rune >= zero && rune < zero + _digitsInBase) {
        return _asciiZero + rune - zero;
      }
    }
    return rune;
  }

  /// The code in ASCII digits with whitespace and direction marks taken out,
  /// or null when what is left is not exactly [length] digits. Mail clients
  /// often show the code spaced out, and a Persian keyboard types it in
  /// Persian digits; both are how it arrives.
  static String? normalize(String raw) {
    final compact = String.fromCharCodes(
      raw.replaceAll(_ignored, '').runes.map(_toAscii),
    );
    return _digits.hasMatch(compact) ? compact : null;
  }
}
