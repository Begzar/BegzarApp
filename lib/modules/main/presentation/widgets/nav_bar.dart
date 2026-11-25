import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/widgets/update_dot.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The bar that switches the three tabs: a solid raised surface, with the tab
/// that is showing raised on a tinted pill in the accent.
///
/// It is solid rather than frosted glass because a blur behind it re-ran on
/// every frame anything moved under it, which held the GPU busy enough to
/// stutter the notification shade. Every list instead leaves
/// [NavBar.clearance] below its last row, so nothing ends under the bar.
///
/// The settings tab carries a dot for as long as a newer release waits; the
/// row offering it sits at the foot of the settings list.
class NavBar extends ConsumerWidget {
  const NavBar({super.key, required this.selected, required this.onSelect});

  static const bottomInset = AppLayout.mainNavBottomInset;
  static const height = AppLayout.mainNavHeight;
  static const footprint = AppLayout.mainNavFootprint;
  static const clearance = AppLayout.mainNavClearance;

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAvailable = ref.watch(
      availableUpdateProvider.select((update) => update != null),
    );
    final palette = MainPalette.of(context);
    final radius = BorderRadius.circular(AppLayout.mainNavRadius.r);

    return Center(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.all(AppLayout.mainNavPadding.w),
            decoration: BoxDecoration(
              color: palette.navFill,
              borderRadius: radius,
              border: Border.all(color: palette.navRim),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavSeat(
                  icon: Iconsax.setting_2_copy,
                  label: context.l10n.navSettings,
                  isSelected: selected == settingIndex,
                  marked: updateAvailable,
                  onTap: () => onSelect(settingIndex),
                ),
                SizedBox(width: AppLayout.mainNavGap.w),
                _NavSeat(
                  icon: Iconsax.home_copy,
                  label: context.l10n.navHome,
                  isSelected: selected == homeIndex,
                  onTap: () => onSelect(homeIndex),
                ),
                SizedBox(width: AppLayout.mainNavGap.w),
                _NavSeat(
                  icon: Iconsax.user_copy,
                  label: context.l10n.navPremium,
                  isSelected: selected == premiumIndex,
                  onTap: () => onSelect(premiumIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSeat extends StatelessWidget {
  const _NavSeat({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.marked = false,
  });

  static const _duration = Duration(milliseconds: 200);

  final IconData icon;

  /// The tab's name, for a screen reader: the glyph alone says nothing.
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Whether a newer release waits behind this tab.
  final bool marked;

  /// The update dot, labelled because a dot alone tells a screen reader
  /// nothing.
  Widget _updateDot(BuildContext context) {
    final overhang = -AppLayout.mainNavUpdateDotOverhang.w;
    return Positioned(
      top: overhang,
      right: overhang,
      // Its own node, so the tab's name and the dot are announced apart
      // rather than run together into one label.
      child: Semantics(
        container: true,
        child: UpdateDot(semanticLabel: context.l10n.updateAvailableTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MainPalette.of(context);
    final radius = BorderRadius.circular(AppLayout.mainNavSeatRadius.r);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
      duration: _duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Container(
          width:
              (AppLayout.mainNavRestingWidth +
                      AppLayout.mainNavSelectedGrowth * t)
                  .w,
          height: AppLayout.mainNavSeatHeight.w,
          // The fill and rim carry alphas of their own, so the selection
          // scales them rather than replacing them.
          decoration: BoxDecoration(
            borderRadius: radius,
            color: palette.navSelected.withValues(
              alpha: palette.navSelected.a * t,
            ),
            border: Border.all(
              color: palette.navSelectedRim.withValues(
                alpha: palette.navSelectedRim.a * t,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              button: true,
              selected: isSelected,
              label: label,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: Color.lerp(
                          palette.navResting,
                          palette.navOnSelected,
                          t,
                        ),
                        size:
                            (AppLayout.mainNavRestingGlyph +
                                    AppLayout.mainNavSelectedGlyphGrowth * t)
                                .sp,
                      ),
                      if (marked) _updateDot(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
