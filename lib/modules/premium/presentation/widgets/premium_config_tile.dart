import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_config_ping_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One dialable config inside an expanded server card.
///
/// Tapping it connects, or — when it is the config already connected —
/// disconnects. The active row carries no word of its own for that: the
/// header's Disconnect and the hint under the title already say it, and a red
/// word on the row made three on one sheet.
class PremiumConfigTile extends StatelessWidget {
  const PremiumConfigTile({
    super.key,
    required this.name,
    required this.isActive,
    required this.isConnecting,
    required this.isLastConnected,
    required this.pingState,
    required this.enabled,
    required this.onTap,
  });

  final String name;

  /// The tunnel is up through this config.
  final bool isActive;

  /// A connect through this config has been asked for and not yet answered.
  final bool isConnecting;

  /// Used last time, and not connected now.
  final bool isLastConnected;

  final ConfigPingState? pingState;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.premiumConfigPadH.w,
            vertical: AppLayout.premiumConfigPadV.h,
          ),
          child: Row(
            children: [
              Container(
                width: AppLayout.premiumConfigDotSize.w,
                height: AppLayout.premiumConfigDotSize.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? palette.blue
                      : isLastConnected
                      ? palette.blue.withValues(
                          alpha: PremiumPalette.historyAlpha,
                        )
                      : palette.textMuted,
                ),
              ),
              SizedBox(width: AppLayout.premiumConfigGap.w),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontFamily: monoFamilyOf(context),
                          fontSize: AppLayout.textLg.sp,
                          fontWeight: isActive
                              ? FontWeight.w500
                              : FontWeight.w300,
                        ),
                      ),
                    ),
                    SizedBox(width: AppLayout.premiumConfigBadgeGap.w),
                    // Flexible alongside the name: the latency carries its unit
                    // spelled out in the language on screen, and the Persian
                    // for milliseconds is a whole word rather than the two
                    // letters the row was laid out around. Both it and the name
                    // give ground now instead of the row running out of it.
                    Flexible(
                      child: PremiumConfigPingBadge(pingState: pingState),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppLayout.premiumConfigBadgeGap.w),
              _trailing(context),
            ],
          ),
        ),
      ),
    );
  }

  /// What closes the row: a spinner while a connect through it is under way,
  /// otherwise a badge saying the tunnel is up through it or was last time.
  ///
  /// Both badges sit here rather than beside the name, so where the tunnel is
  /// and where it was are read in the same place on every row.
  ///
  /// A row that is neither used to carry a
  /// struck-through shield, which said "not connected" on every row in the
  /// list at once — a column of identical glyphs marking the ordinary state,
  /// leaving the reader to find the one row that differed. The dot at the
  /// other end already says which that is.
  Widget _trailing(BuildContext context) {
    final palette = PremiumPalette.of(context);

    if (isConnecting) {
      return SizedBox(
        width: AppLayout.premiumConfigSpinner.w,
        height: AppLayout.premiumConfigSpinner.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: palette.amberInk,
        ),
      );
    }

    if (isActive) {
      return PremiumConnectionBadge(
        label: context.l10n.configConnected,
        isLive: true,
      );
    }

    if (isLastConnected) {
      return PremiumConnectionBadge(label: context.l10n.lastConnected);
    }

    return const SizedBox.shrink();
  }
}

/// Marks where the tunnel is, or what the user connected through last time,
/// so a list of similar names has one obvious starting point.
///
/// The live one is a solid accent and the remembered one a tint of it: the
/// same hue at two weights, so the live one outranks the other at a glance.
class PremiumConnectionBadge extends StatelessWidget {
  const PremiumConnectionBadge({
    super.key,
    required this.label,
    this.isLive = false,
  });

  final String label;

  /// The tunnel is up through what this badge marks.
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumConfigBadgePadH.w,
        vertical: AppLayout.premiumConfigBadgePadV.h,
      ),
      decoration: BoxDecoration(
        color: isLive
            ? palette.blue
            : palette.blue.withValues(alpha: PremiumPalette.badgeFillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.premiumCardRadius.r),
        border: Border.all(
          color: isLive
              ? palette.blue
              : palette.blue.withValues(alpha: PremiumPalette.liveAlpha),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isLive ? palette.onAccent : palette.badgeText,
          fontSize: AppLayout.textXs.sp,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
