import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/support/support_contact.dart';
import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_dialog_frame.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_page.dart';
import 'package:begzar/modules/premium/presentation/widgets/purchase_destination_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

void _showPremiumStyledDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required Color iconBackground,
  required String title,
  required String message,
  required String primaryLabel,
  required Widget primaryMark,
  required Future<void> Function() onPrimary,
  required Color primaryColor,
}) {
  showDialog<void>(
    context: context,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    builder: (dialogContext) {
      return PremiumDialogFrame(
        icon: icon,
        iconColor: iconColor,
        iconBackground: iconBackground,
        title: title,
        message: message,
        onCancel: () => Navigator.of(dialogContext).pop(),
        action: PremiumDialogAction(
          label: primaryLabel,
          color: primaryColor,
          mark: primaryMark,
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            await onPrimary();
          },
        ),
      );
    },
  );
}

/// Offers premium. [purchase] decides whether the tap opens the bot or the
/// website, and the button's mark follows it. A Play build shows the paywall
/// in its place: the same popup, with the plans in it.
void showPremiumPurchaseDialog(
  BuildContext context,
  ConnectionStatus status,
  PremiumPurchaseLauncher purchase,
) {
  if (purchase.sellsThroughGooglePlay) {
    showPremiumPaywall(context);
    return;
  }
  final l10n = context.l10n;
  final palette = PremiumPalette.of(context);
  _showPremiumStyledDialog(
    context: context,
    icon: Iconsax.crown_1,
    iconColor: palette.offerBuy,
    iconBackground: palette.offerBuy.withValues(
      alpha: PremiumDialogFrame.iconBackgroundAlpha,
    ),
    title: l10n.premiumDialogTitle,
    message: l10n.premiumDialogMessage,
    primaryLabel: l10n.buyPremium,
    primaryMark: PurchaseDestinationMark(size: AppLayout.premiumDialogMark.sp),
    onPrimary: purchase.open,
    primaryColor: palette.offerBuy,
  );
}

/// A renewal is a purchase, so it goes wherever a first purchase would.
void showSubscriptionExpiredDialog(
  BuildContext context,
  ConnectionStatus status,
  PremiumPurchaseLauncher purchase,
) {
  if (purchase.sellsThroughGooglePlay) {
    showPremiumPaywall(context, renewal: true);
    return;
  }
  final l10n = context.l10n;
  final palette = PremiumPalette.of(context);
  _showPremiumStyledDialog(
    context: context,
    icon: Iconsax.calendar_remove,
    iconColor: palette.offerRenew,
    iconBackground: palette.offerRenew.withValues(
      alpha: PremiumDialogFrame.iconBackgroundAlpha,
    ),
    title: l10n.subscriptionExpiredTitle,
    message: l10n.subscriptionExpiredMessage,
    primaryLabel: l10n.renewSubscription,
    primaryMark: PurchaseDestinationMark(size: AppLayout.premiumDialogMark.sp),
    onPrimary: purchase.open,
    primaryColor: palette.offerRenew,
  );
}

void showAccountInactiveDialog(BuildContext context, ConnectionStatus status) {
  final l10n = context.l10n;
  final palette = PremiumPalette.of(context);
  _showPremiumStyledDialog(
    context: context,
    icon: Iconsax.user_remove,
    iconColor: palette.offerRestore,
    iconBackground: palette.offerRestore.withValues(
      alpha: PremiumDialogFrame.iconBackgroundAlpha,
    ),
    title: l10n.accountInactiveTitle,
    message: l10n.accountInactiveMessage,
    primaryLabel: l10n.contactSupport,
    primaryMark: TelegramMark(size: AppLayout.premiumDialogMark.sp),
    onPrimary: () => openSupportTelegram(
      context,
      message: l10n.accountInactiveSupportMessage,
    ),
    primaryColor: palette.offerRestore,
  );
}
