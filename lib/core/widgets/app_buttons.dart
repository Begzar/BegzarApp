import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The one action a screen is asking for.
///
/// One shape for every screen that asks for something, which the app did not
/// have: the premium module owned a primary button, and five other places
/// wrote their own `styleFrom` beside it rather than reach across a module
/// boundary for it. Between them they used three vertical paddings and two
/// corner radii for the same control, and the notification gate — the first
/// screen a new install sees — used a sixth combination and a blue nothing
/// else in the app uses.
///
/// The colour is the caller's, because what the action means is the caller's:
/// a subscription is green, a warning amber, a settings save the settings
/// accent. The geometry is not.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.onColor,
    this.icon,
    this.isLoading = false,
  });

  final String label;

  /// The fill.
  final Color color;

  /// Null disables the button; the fill dims rather than disappearing, so the
  /// control keeps its place while the action it started is in flight.
  final VoidCallback? onPressed;

  /// The label. Defaults to whichever ink reads on [color].
  final Color? onColor;
  final IconData? icon;

  /// Swaps the label for a spinner in place, so the button does not resize
  /// while the action runs.
  final bool isLoading;

  /// How far the fill dims when the button is disabled — still visible as a
  /// control, clearly not one that can be pressed.
  static const _disabledAlpha = 0.4;

  @override
  Widget build(BuildContext context) {
    final onColor = this.onColor ?? AppPalette.labelOn(color);
    final style = ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: onColor,
      disabledBackgroundColor: color.withValues(alpha: _disabledAlpha),
      disabledForegroundColor: onColor.withValues(alpha: _disabledAlpha),
      elevation: 0,
      padding: EdgeInsets.symmetric(
        vertical: AppLayout.buttonPadV.h,
        horizontal: AppLayout.buttonPadH.w,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.buttonRadius.r),
      ),
    );

    if (isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: style,
        child: SizedBox.square(
          dimension: AppLayout.buttonLabel.sp,
          child: CircularProgressIndicator(
            strokeWidth: _spinnerStroke,
            color: onColor,
          ),
        ),
      );
    }

    final text = Text(
      label,
      style: TextStyle(
        fontSize: AppLayout.buttonLabel.sp,
        fontWeight: FontWeight.w600,
      ),
    );

    if (icon == null) {
      return ElevatedButton(onPressed: onPressed, style: style, child: text);
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: AppLayout.buttonLabel.sp),
      label: text,
    );
  }

  static const _spinnerStroke = 2.0;
}

/// A confirm sitting at the foot of a dialog, beside a cancel.
///
/// Smaller than [AppPrimaryButton] on purpose: a dialog asks one short
/// question, and a full-width fill under it outweighs the question.
class AppCompactButton extends StatelessWidget {
  const AppCompactButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.onColor,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  /// The label. Defaults to whichever ink reads on [color].
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: onColor ?? AppPalette.labelOn(color),
        padding: EdgeInsets.symmetric(
          vertical: AppLayout.buttonCompactPadV.h,
          horizontal: AppLayout.buttonCompactPadH.w,
        ),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.buttonRadius.r),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.buttonCompactLabel.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
