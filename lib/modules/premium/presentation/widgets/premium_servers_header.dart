import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/main/presentation/controllers/main_screen_controller.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The title above the premium list, and the one control beside it.
///
/// That control swaps with the tunnel: refresh while nothing is connected,
/// disconnect while something is. Two actions in one slot rather than two
/// slots, because only ever one of them is the thing to do next.
class PremiumServersHeader extends ConsumerWidget {
  const PremiumServersHeader({
    super.key,
    required this.state,
    required this.isConnected,
    required this.isBusy,
  });

  final PremiumServersState state;

  /// Connected or on the way down — either way the list is not what the user
  /// is about to act on.
  final bool isConnected;

  /// A connect or disconnect is in flight.
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.premiumServersTitle,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontFamily: displayFamilyOf(context),
                  fontSize: AppLayout.text6xl.sp,
                  // The display face is drawn at the weight the design sets
                  // it in; the body face keeps its own light heading.
                  fontWeight: displayFamilyOf(context) == null
                      ? FontWeight.w300
                      : FontWeight.w500,
                  height: 1.2,
                ),
              ),
              SizedBox(height: AppLayout.premiumHeaderLabelGap.h),
              Text(
                isConnected
                    ? l10n.premiumServersConnectedHintFor(
                        Theme.of(context).platform,
                      )
                    : l10n.premiumServersSubtitle,
                style: TextStyle(
                  color: isConnected ? palette.blue : palette.textTertiary,
                  fontSize: AppLayout.textBase.sp,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: PremiumPalette.swap,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.86, end: 1).animate(animation),
                child: child,
              ),
            );
          },
          child: isConnected
              ? _DisconnectButton(
                  key: const ValueKey('disconnect'),
                  label: l10n.disconnect,
                  isLoading: isBusy,
                  onTap: isBusy
                      ? null
                      : () => ref.read(mainScreenProvider).stopConnection(),
                )
              : _RefreshButton(
                  key: const ValueKey('refresh'),
                  isLoading: state.isLoading,
                  onTap: state.isLoading
                      ? null
                      : () => ref
                            .read(premiumServersProvider.notifier)
                            .load(force: true),
                ),
        ),
      ],
    );
  }
}

/// Reloads the list.
///
/// A frosted square rather than the solid grey circle it used to be: that
/// circle was the appbar's button, and a control borrowed from the bar at the
/// top of the screen read as belonging to the bar rather than to the list it
/// sits on. This is the treatment the ping reading uses for the icon it opens
/// with — the same glass the rest of this screen is built from.
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({super.key, required this.isLoading, this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AppGlassPanel(
        style: AppGlass.chip(
          context.palette,
          cornerRadius: AppLayout.premiumChipRadius.r,
        ),
        child: SizedBox(
          width: AppLayout.premiumHeaderButtonSize.w,
          height: AppLayout.premiumHeaderButtonSize.w,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: AppLayout.premiumHeaderSpinner.w,
                    height: AppLayout.premiumHeaderSpinner.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textPrimary,
                    ),
                  )
                : Icon(
                    Iconsax.refresh,
                    color: palette.textPrimary,
                    size: AppLayout.premiumHeaderGlyph.sp,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Drops the tunnel from inside the list.
///
/// It takes the refresh button's chip, so the slot keeps its shape when the
/// two swap. Only the glyph is red, as on the account tab's Sign out: the
/// label stays in the text ink, which a red word on a red wash fell short of
/// on a light page.
class _DisconnectButton extends StatelessWidget {
  const _DisconnectButton({
    super.key,
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AppGlassPanel(
        style: AppGlass.chip(
          context.palette,
          cornerRadius: AppLayout.premiumChipRadius.r,
        ),
        child: Container(
          height: AppLayout.premiumHeaderButtonSize.w,
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.premiumHeaderTogglePadH.w,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: AppLayout.premiumHeaderToggleSpinner.w,
                  height: AppLayout.premiumHeaderToggleSpinner.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.red,
                  ),
                )
              else
                Icon(
                  Iconsax.shield_cross_copy,
                  color: palette.red,
                  size: AppLayout.premiumHeaderDisconnectGlyph.sp,
                ),
              SizedBox(width: AppLayout.premiumHeaderDisconnectGap.w),
              Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: AppLayout.textBase.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
