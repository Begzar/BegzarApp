import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// How far away one config's server is, as an antenna and a number.
///
/// Three states rather than two: not measured yet shows nothing at all, so a
/// row that has never been pinged does not claim the server is unreachable.
class PremiumConfigPingBadge extends StatelessWidget {
  const PremiumConfigPingBadge({super.key, required this.pingState});

  final ConfigPingState? pingState;

  static const _unreachableLabel = '—';

  /// One duration for the swap and for the resize it causes, so the reading
  /// finishes arriving exactly as the room made for it finishes closing.
  static const _transition = Duration(milliseconds: 240);

  /// The longest latency worth reserving room for. Measurements above this are
  /// reported as unreachable long before the digits would matter.
  static const _widestReading = 1234;

  @override
  Widget build(BuildContext context) {
    final state = pingState;

    // Keying on the outcome, not the object: an identical re-measurement
    // should not replay the transition.
    final key = state == null
        ? 'none'
        : state.isLoading
        ? 'loading'
        : state.failed || state.latencyMs == null
        ? 'fail'
        : 'ok-${state.latencyMs}';

    return AnimatedSize(
      duration: _transition,
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.centerStart,
      child: AnimatedSwitcher(
        duration: _transition,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // The default stacks the outgoing and incoming children centred, so
        // a reading narrower than the shimmer it replaces lands re-centred —
        // the icon and number visibly stepping across as they arrive. Anchored
        // to the reading direction's start, they arrive where they will stay.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(key),
          child: _content(context, state),
        ),
      ),
    );
  }

  /// How wide the reading gets in the language on screen.
  ///
  /// Measured rather than stated. This used to be a constant sized to `1234ms`,
  /// which was the widest reading only while the unit was the hardcoded English
  /// `ms` — the Persian for milliseconds is a whole word, and a placeholder cut
  /// to English left the row reflowing the moment a real measurement replaced
  /// it. The row absorbs the difference in the config name beside it, so a
  /// placeholder of the wrong width is a name that changes length for no
  /// reason the reader can see.
  double _placeholderWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.pingMs(_widestReading),
        style: TextStyle(
          fontSize: AppLayout.premiumPingLabelSize.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width +
        AppLayout.premiumPingIconSize.sp +
        AppLayout.premiumPingIconGap.w;
  }

  Widget _content(BuildContext context, ConfigPingState? state) {
    if (state == null) return const SizedBox.shrink();
    final palette = PremiumPalette.of(context);

    if (state.isLoading) {
      final veil = context.palette.veil;
      return Shimmer.fromColors(
        baseColor: veil.withValues(alpha: 0.12),
        highlightColor: veil.withValues(alpha: 0.35),
        child: Container(
          width: _placeholderWidth(context),
          height: AppLayout.premiumPingShimmerHeight.h,
          decoration: BoxDecoration(
            color: veil,
            borderRadius: BorderRadius.circular(
              AppLayout.premiumDeviceRowRadius.r,
            ),
          ),
        ),
      );
    }

    if (state.failed || state.latencyMs == null) {
      return _Reading(
        icon: Iconsax.chart_2_copy,
        color: palette.signalUnreachable,
        label: _unreachableLabel,
        labelAlpha: 0.9,
      );
    }

    final strong = state.isStrongSignal;
    return _Reading(
      icon: strong ? Iconsax.status_up_copy : Iconsax.chart_2_copy,
      color: strong ? palette.signalStrong : palette.signalWeak,
      // Was '${state.latencyMs}ms', which was English in every language and
      // Latin-digit in Persian. The pill on the home screen already said this
      // properly; this row was the one place saying it by hand.
      label: context.l10n.pingMs(state.latencyMs!),
      weight: FontWeight.w500,
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.icon,
    required this.color,
    required this.label,
    this.labelAlpha = 1,
    this.weight = FontWeight.w400,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double labelAlpha;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppLayout.premiumPingIconSize.sp, color: color),
        SizedBox(width: AppLayout.premiumPingIconGap.w),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color.withValues(alpha: labelAlpha),
            fontFamily: monoFamilyOf(context),
            fontSize: AppLayout.premiumPingLabelSize.sp,
            fontWeight: weight,
          ),
        ),
      ],
    );
  }
}
