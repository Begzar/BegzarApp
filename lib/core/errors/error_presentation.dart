import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/l10n/app_localizations.dart';

/// Localized message, optional recovery hint, and whether to offer the
/// Premium bot. Built from a stored l10n key at the toast/banner.
class ErrorPresentation {
  const ErrorPresentation({
    required this.message,
    this.hint,
    this.showPremiumHelp = false,
  });

  final String message;
  final String? hint;
  final bool showPremiumHelp;

  static const premiumHelpKeys = {
    UserFacingErrorKeys.invalidCredentials,
    UserFacingErrorKeys.sessionCredentials,
    UserFacingErrorKeys.deviceLimit,
    UserFacingErrorKeys.accountDisabled,
    UserFacingErrorKeys.accountExpired,
  };

  factory ErrorPresentation.fromKey(
    String? key,
    AppLocalizations l10n, {
    int? retryAfterSeconds,
  }) {
    final resolved = key == null || key.trim().isEmpty
        ? UserFacingErrorKeys.connectionFailed
        : (isUserFacingErrorKey(key)
              ? key.trim()
              : resolveUserFacingErrorKey(key));
    return ErrorPresentation(
      message: l10n.translateError(resolved),
      hint: l10n.errorHint(resolved, retryAfterSeconds: retryAfterSeconds),
      showPremiumHelp: premiumHelpKeys.contains(resolved),
    );
  }
}
