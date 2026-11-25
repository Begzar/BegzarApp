import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_devices_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_dialog_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:begzar/l10n/localized_date.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// One device registration, as its own tile, with the control to unlink it.
///
/// The tile for this install shows a label instead of a remove button: signing
/// this device out is what the account screen's sign-out is for, and removing
/// it from here would strand the user in a signed-in app with no seat.
class PremiumDeviceRow extends ConsumerWidget {
  const PremiumDeviceRow({
    super.key,
    required this.device,
    required this.isCurrent,
    required this.isRemoving,
    required this.canRemove,
  });

  final PremiumDevice device;
  final bool isCurrent;

  /// This row's removal is in flight.
  final bool isRemoving;

  /// No removal is in flight anywhere, and this is not the current device.
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final box = AppLayout.premiumDeviceIconBox.w;

    return Container(
      padding: EdgeInsets.all(AppLayout.premiumDeviceCardPad.w),
      decoration: BoxDecoration(
        color: palette.inkSurface,
        borderRadius: BorderRadius.circular(
          AppLayout.premiumDeviceCardRadius.r,
        ),
        border: Border.all(color: palette.inkLine),
      ),
      child: Row(
        children: [
          Container(
            width: box,
            height: box,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.inkSurfaceRaised,
              borderRadius: BorderRadius.circular(
                AppLayout.premiumDeviceIconRadius.r,
              ),
            ),
            child: Icon(
              Iconsax.mobile,
              size: AppLayout.premiumDeviceGlyph.sp,
              color: palette.inkText,
            ),
          ),
          SizedBox(width: AppLayout.premiumDeviceCardGap.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: TextStyle(
                    fontSize: AppLayout.premiumDeviceName.sp,
                    fontWeight: FontWeight.w600,
                    color: palette.inkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (device.loggedInAt != null) ...[
                  SizedBox(height: AppLayout.premiumDeviceSubGap.h),
                  Text(
                    l10n.deviceLoggedInAt(
                      LocalizedDate.dayAndTime(
                        device.loggedInAt!.toLocal(),
                        l10n.localeName,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: monoFamilyOf(context),
                      fontSize: AppLayout.premiumDeviceSub.sp,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: AppLayout.premiumDeviceActionGap.w),
          _trailing(context, ref, l10n),
        ],
      ),
    );
  }

  Widget _tag(String label, Color colour) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumDeviceTagPadH.w,
        vertical: AppLayout.premiumDeviceTagPadV.h,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: PremiumPalette.chipFillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.premiumDeviceTagRadius.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.premiumDeviceTagLabel.sp,
          color: colour,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final palette = PremiumPalette.of(context);
    if (isCurrent) return _tag(l10n.thisDevice, palette.good);

    if (isRemoving) {
      return SizedBox(
        width: AppLayout.premiumDeviceSpinner.w,
        height: AppLayout.premiumDeviceSpinner.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: palette.inkMuted,
        ),
      );
    }

    return GestureDetector(
      onTap: canRemove ? () => _confirmRemove(context, ref) : null,
      child: Opacity(
        opacity: canRemove ? 1 : PremiumPalette.dimmedAlpha,
        child: _tag(l10n.removeDevice, palette.danger),
      ),
    );
  }

  /// Confirms first: unlinking is immediate on the server, and the other
  /// device finds out by being signed out.
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final palette = PremiumPalette.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Drawn in the frame every premium popup shares, like deleting the
    // account, the screen's other irreversible step.
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
      builder: (dialogContext) => PremiumDialogFrame(
        icon: Iconsax.mobile,
        iconColor: palette.red,
        iconBackground: palette.red.withValues(
          alpha: PremiumDialogFrame.iconBackgroundAlpha,
        ),
        title: l10n.removeDeviceTitle,
        message: l10n.removeDeviceMessage(device.deviceName),
        onCancel: () => Navigator.pop(dialogContext, false),
        action: PremiumDialogAction(
          label: l10n.removeDevice,
          color: palette.red,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
    );

    if (confirmed != true) return;

    final refusal = await ref
        .read(premiumDevicesProvider.notifier)
        .removeDevice(device.deviceId);

    // A refusal takes the error toast every other error uses, which carries
    // the hint and the way to support that a plain snackbar has no room for.
    if (refusal != null) {
      if (context.mounted) showTopErrorPopup(context, refusal);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.deviceRemovedSuccess),
        backgroundColor: palette.snackSuccess,
      ),
    );
  }
}
