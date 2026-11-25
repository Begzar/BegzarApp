import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Two choices in one control, the chosen one raised on a sliding thumb:
/// signing in, or creating an account.
///
/// It replaces the pair of text links that used to sit under each form. Both
/// halves are now in view before anything is typed, so nobody fills in the
/// sign-in form to find out they wanted the other one.
class PremiumSegmentedSwitch extends StatelessWidget {
  const PremiumSegmentedSwitch({
    super.key,
    required this.startLabel,
    required this.endLabel,
    required this.endSelected,
    required this.onChanged,
  });

  final String startLabel;
  final String endLabel;

  /// Whether the second choice is the one showing.
  final bool endSelected;

  /// Called with true for the second choice. Null locks the control, while a
  /// request from either half is in flight.
  final ValueChanged<bool>? onChanged;

  /// The thumb covers one of the two halves.
  static const _half = 0.5;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final change = onChanged;

    return Container(
      padding: EdgeInsets.all(AppLayout.premiumSegmentPad.w),
      decoration: BoxDecoration(
        color: palette.inkSurface,
        borderRadius: BorderRadius.circular(AppLayout.premiumSegmentRadius.r),
        border: Border.all(color: palette.inkLine),
      ),
      child: SizedBox(
        height: AppLayout.premiumSegmentHeight.h,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: endSelected
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                duration: PremiumPalette.swap,
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: _half,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.inkSurfaceRaised,
                      borderRadius: BorderRadius.circular(
                        AppLayout.premiumSegmentThumbRadius.r,
                      ),
                      border: Border.all(color: palette.inkLineStrong),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: _Segment(
                      label: startLabel,
                      selected: !endSelected,
                      onTap: change == null ? null : () => change(false),
                    ),
                  ),
                  Expanded(
                    child: _Segment(
                      label: endLabel,
                      selected: endSelected,
                      onTap: change == null ? null : () => change(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: PremiumPalette.stateChange,
            style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: AppLayout.premiumSegmentLabel.sp,
              fontWeight: FontWeight.w500,
              color: selected ? palette.inkText : palette.inkMuted,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
