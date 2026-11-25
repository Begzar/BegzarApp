import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/app_update_palette.dart';
import 'package:flutter/material.dart';

/// Opens the page a newer build comes from, and says so when it will not open.
///
/// Shared by the forced-update dialog and the settings update row, so a
/// missing or refused page reads the same wherever the user asked for it.
abstract final class UpdatePageLauncher {
  /// Still a snackbar, and deliberately so for now: `showTopErrorPopup` — what
  /// the rest of the app raises failures with — takes a `UserFacingErrorKeys`
  /// value rather than a string, and neither of these two messages has a key.
  /// One of them also carries the exception text, which that path has no way
  /// to pass. Registering the keys is its own change.
  static void _reportFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppUpdatePalette.of(context).snackFailure,
      ),
    );
  }

  static Future<void> open(BuildContext context, String? url) async {
    final page = url?.trim() ?? '';
    if (page.isEmpty) {
      _reportFailure(context, context.l10n.updateOpenFailed);
      return;
    }

    try {
      final opened = await NativeUrlLauncher.open(page);
      if (!opened && context.mounted) {
        _reportFailure(context, context.l10n.updateOpenFailed);
      }
    } catch (e) {
      if (context.mounted) {
        _reportFailure(context, context.l10n.updateError('$e'));
      }
    }
  }
}
