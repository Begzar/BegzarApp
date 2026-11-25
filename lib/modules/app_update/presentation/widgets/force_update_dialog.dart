import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass_dialog.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/app_update_palette.dart';
import 'package:begzar/modules/app_update/presentation/update_page_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Force Update Dialog
/// Non-dismissible dialog that forces user to update the app
class ForceUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;
  final String? updateUrl;

  const ForceUpdateDialog({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
    this.updateUrl,
  });

  /// Show the force update dialog — never dismissible.
  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required String requiredVersion,
    String? updateUrl,
  }) {
    // A build too old is often told so before the launch cover has carried
    // its dial into home; the dial must not travel over this dialog, so the
    // cover fades where it is instead.
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(launchCoverProvider.notifier).dismiss();
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: ForceUpdateDialog(
          currentVersion: currentVersion,
          requiredVersion: requiredVersion,
          updateUrl: updateUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppUpdatePalette.of(context);

    // The shared shell, not a hand-rolled one: this dialog used to build its
    // own `Dialog` around the same glass panel, which left it a few points off
    // the radius and inset every other dialog in the app uses, and out of
    // reach of any change made to them.
    return AppGlassDialog(
      // Two points wider than the shell's default, which is the width this
      // dialog's description was written to. At the default it wraps to three
      // lines and leaves the last word on its own.
      insetPadding: EdgeInsets.symmetric(
        horizontal: AppLayout.updateDialogInset.w,
      ),
      padding: EdgeInsets.fromLTRB(
        AppLayout.updateDialogPadH.w,
        AppLayout.updateDialogPadTop.h,
        AppLayout.updateDialogPadH.w,
        AppLayout.updateDialogPadBottom.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, palette),
          SizedBox(height: AppLayout.updateHeaderToCard.h),
          _buildVersionCard(context, palette),
          SizedBox(height: AppLayout.updateCardToButton.h),
          _buildUpdateButton(context, palette),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppUpdatePalette palette) {
    return Column(
      children: [
        // The ring alone: no halo behind it and no glow under it. On this app
        // only the dial casts a glow, and its glow is the connection's state.
        Container(
          width: AppLayout.updateRingSize.w,
          height: AppLayout.updateRingSize.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.ringTop, palette.ringBottom],
            ),
            border: Border.all(
              color: palette.ringBorder,
              width: AppLayout.updateRingBorderWidth,
            ),
          ),
          child: Icon(
            Iconsax.cloud_add,
            size: AppLayout.updateMarkGlyph.sp,
            color: palette.ringGlyph,
          ),
        ),
        SizedBox(height: AppLayout.updateMarkToTitle.h),
        Text(
          context.l10n.updateRequired,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppLayout.text6xl.sp,
            fontWeight: FontWeight.w700,
            color: palette.text,
            height: 1.2,
          ),
        ),
        SizedBox(height: AppLayout.updateTitleToBody.h),
        Text(
          context.l10n.updateDescription,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppLayout.textXl.sp,
            color: palette.textMuted.withValues(
              alpha: AppUpdatePalette.descriptionAlpha,
            ),
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionCard(BuildContext context, AppUpdatePalette palette) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppLayout.updateCardPad.w),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppLayout.updateCardRadius.r),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          _versionTile(
            palette,
            label: context.l10n.currentVersion,
            version: currentVersion,
            icon: Iconsax.mobile,
            accent: palette.warn,
            muted: true,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppLayout.updateStepGap.h),
            child: Row(
              children: [
                Expanded(child: Divider(color: palette.divider, height: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.updateStepGap.w,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(AppLayout.updateStepBadgePad.w),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(
                        alpha: AppUpdatePalette.stepBadgeAlpha,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.arrow_down_1,
                      size: AppLayout.updateStepGlyph.sp,
                      color: palette.accent,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: palette.divider, height: 1)),
              ],
            ),
          ),
          _versionTile(
            palette,
            label: context.l10n.requiredVersion,
            version: requiredVersion,
            icon: Iconsax.verify,
            accent: palette.accent,
            muted: false,
          ),
        ],
      ),
    );
  }

  Widget _versionTile(
    AppUpdatePalette palette, {
    required String label,
    required String version,
    required IconData icon,
    required Color accent,
    required bool muted,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.updateTilePadH.w,
        vertical: AppLayout.updateTilePadV.h,
      ),
      decoration: BoxDecoration(
        color: muted
            ? palette.mutedFill
            : accent.withValues(alpha: AppUpdatePalette.activeFillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.updateTileRadius.r),
        border: Border.all(
          color: muted
              ? palette.mutedBorder
              : accent.withValues(alpha: AppUpdatePalette.activeBorderAlpha),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppLayout.updateIconBoxSize.w,
            height: AppLayout.updateIconBoxSize.w,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: muted
                    ? AppUpdatePalette.iconBoxMutedAlpha
                    : AppUpdatePalette.iconBoxAlpha,
              ),
              borderRadius: BorderRadius.circular(
                AppLayout.updateIconBoxRadius.r,
              ),
            ),
            child: Icon(
              icon,
              size: AppLayout.updateTileGlyph.sp,
              color: accent,
            ),
          ),
          SizedBox(width: AppLayout.updateTileGlyphGap.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppLayout.textMd.sp,
                    color: palette.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: AppLayout.updateTileLabelGap.h),
                Text(
                  version,
                  style: TextStyle(
                    fontSize: AppLayout.text2xl.sp,
                    fontWeight: FontWeight.w700,
                    color: muted
                        ? palette.text.withValues(
                            alpha: AppUpdatePalette.mutedVersionAlpha,
                          )
                        : palette.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton(BuildContext context, AppUpdatePalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppLayout.updateButtonRadius.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, palette.accentDeep],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => UpdatePageLauncher.open(context, updateUrl),
          borderRadius: BorderRadius.circular(AppLayout.updateButtonRadius.r),
          child: SizedBox(
            width: double.infinity,
            height: AppLayout.updateButtonHeight.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.import_1,
                  size: AppLayout.updateButtonGlyph.sp,
                  color: AppUpdatePalette.onButton,
                ),
                SizedBox(width: AppLayout.updateButtonGlyphGap.w),
                Text(
                  context.l10n.updateNow,
                  style: TextStyle(
                    fontSize: AppLayout.text3xl.sp,
                    fontWeight: FontWeight.w700,
                    color: AppUpdatePalette.onButton,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
