import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/widgets/force_update_dialog.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_connect_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a refused connect into the dialog that explains it.
///
/// Both ways of asking for a connect — the home dial and a config tapped in
/// the premium list — run the same gate, so they are refused for the same
/// reasons and owe the user the same answer. The mapping was written out once
/// in each of those widgets, and the two had already drifted: a failed
/// entitlement check showed a popup in the list and nothing at all on the home
/// screen.
///
/// Every refusal gets the dialog that offers its own way out — buying,
/// renewing, updating, or contacting support — rather than one generic
/// message.
///
/// [status] is the connection status from *before* the ask. The premium
/// dialogs paint themselves over the status gradient, and what is behind the
/// dialog is the screen the user was looking at when they tapped.
Future<void> showConnectTapExplanation(
  BuildContext context,
  WidgetRef ref,
  ConnectTapOutcome outcome, {
  required ConnectionStatus status,
}) async {
  switch (outcome) {
    case ConnectTapOutcome.updateRequired:
      final force = ref.read(forceUpdateProvider);
      await ForceUpdateDialog.show(
        context,
        currentVersion: force.currentVersion,
        requiredVersion: force.requiredVersion,
        updateUrl: force.updateUrl,
      );
    case ConnectTapOutcome.notEntitled:
      showPremiumPurchaseDialog(
        context,
        status,
        ref.read(premiumPurchaseLauncherProvider),
      );
    case ConnectTapOutcome.subscriptionExpired:
      showSubscriptionExpiredDialog(
        context,
        status,
        ref.read(premiumPurchaseLauncherProvider),
      );
    case ConnectTapOutcome.accountInactive:
      showAccountInactiveDialog(context, status);
    // A popup rather than a dialog: nothing here is actionable, and the next
    // tap may well succeed.
    case ConnectTapOutcome.checkFailed:
      showTopErrorPopup(context, ref.read(premiumProvider).errorMessage);
    case ConnectTapOutcome.ignored:
    case ConnectTapOutcome.errorCleared:
    case ConnectTapOutcome.connecting:
    case ConnectTapOutcome.disconnecting:
    case ConnectTapOutcome.cancelled:
    // Raised by the other-VPN alert, which the server list shares; see
    // `ConnectTapOutcome.needsExplaining`.
    case ConnectTapOutcome.otherVpnOn:
      break;
  }
}
