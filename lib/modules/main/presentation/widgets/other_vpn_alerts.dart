import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_dialog_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// How strongly the warning colour washes the circle behind the icon, as the
/// other connect refusals wash theirs.
const _iconWashAlpha = 0.2;

/// The warning for another VPN Begzar could not turn off, in the frame every
/// other connect refusal uses.
///
/// Its button opens the system's VPN settings, since that is the only place the
/// user can turn it off. Nothing is retried on the way back: the next tap
/// checks again.
///
/// Continue anyway lets whatever raised it go ahead with the VPN on. The check
/// can mistake a modem or an adapter it does not know for a VPN, and without a
/// way past it that mistake would refuse every connect. Every other way out —
/// Cancel, the settings button, a tap outside — answers no.
Future<void> _showOtherVpnWarning(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final palette = context.palette;
  final notifier = ref.read(otherVpnProvider.notifier);
  final goAnyway = await showDialog<bool>(
    context: context,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    builder: (dialogContext) => PremiumDialogFrame(
      icon: Iconsax.warning_2,
      iconColor: palette.warningInk,
      iconBackground: palette.warning.withValues(alpha: _iconWashAlpha),
      title: l10n.otherVpnOnTitle,
      message: l10n.otherVpnOnMessage,
      body: [
        InkQuietButton(
          label: l10n.otherVpnContinueAnyway,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
      onCancel: () => Navigator.of(dialogContext).pop(false),
      action: PremiumDialogAction(
        label: l10n.openSettings,
        color: palette.connected,
        onPressed: () {
          Navigator.of(dialogContext).pop(false);
          notifier.openSettings();
        },
      ),
    ),
  );
  notifier.answerWarning(goAnyway: goAnyway ?? false);
}

/// Tells the user what the other-VPN check found: a notice when Begzar turned
/// the other VPN off and carried on, the warning when it could not.
void showOtherVpnAlert(
  BuildContext context,
  WidgetRef ref,
  OtherVpnVerdict verdict,
) {
  switch (verdict) {
    case OtherVpnVerdict.disconnected:
      showTopNoticePopup(context, context.l10n.otherVpnTurnedOff);
    case OtherVpnVerdict.stillOn:
      _showOtherVpnWarning(context, ref);
    // Raised by the user's own answer to the warning, never as an alert.
    case OtherVpnVerdict.overridden:
    case OtherVpnVerdict.none:
      break;
  }
}
