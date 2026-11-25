import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// The pieces every popup is built from: the glyph it opens with, its title
// and message, its two actions, and its fields.
//
// In core because popups are raised by every module, and five of them had
// grown a look each: a tinted disc, a flat Material button, a stock
// segmented control, a field with no rim. One set of parts is what keeps a
// dialog in settings and a dialog over an ad reading as the same app.

/// The glyph a popup opens with: a tile washed in the popup's colour, with a
/// rim. No light spills round it: on this app only the dial casts a glow, and
/// its glow is the connection's state.
class InkDialogEmblem extends StatelessWidget {
  const InkDialogEmblem({
    super.key,
    required this.icon,
    required this.color,
    this.fill,
  });

  final IconData icon;

  /// The glyph and the rim.
  final Color color;

  /// The tile's wash. Defaults to [color] at [_fillAlpha].
  final Color? fill;

  static const _fillAlpha = 0.12;
  static const _rimAlpha = 0.30;

  @override
  Widget build(BuildContext context) {
    final box = AppLayout.inkEmblem.w;

    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? color.withValues(alpha: _fillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.inkEmblemRadius.r),
        border: Border.all(color: color.withValues(alpha: _rimAlpha)),
      ),
      child: Icon(icon, color: color, size: AppLayout.inkEmblemGlyph.sp),
    );
  }
}

/// A popup's title and the line under it.
class InkDialogText extends StatelessWidget {
  const InkDialogText({
    super.key,
    required this.title,
    this.message,
    this.textAlign = TextAlign.center,
  });

  final String title;
  final String? message;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final message = this.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: TextStyle(
            color: palette.text,
            fontSize: AppLayout.inkDialogTitle.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: AppLayout.inkDialogTitleTracking,
            height: AppLayout.inkDialogTitleLineHeight,
          ),
        ),
        if (message != null) ...[
          SizedBox(height: AppLayout.inkDialogTextGap.h),
          Text(
            message,
            textAlign: textAlign,
            style: TextStyle(
              color: palette.muted,
              fontSize: AppLayout.inkDialogMessage.sp,
              height: AppLayout.inkDialogMessageLineHeight,
            ),
          ),
        ],
      ],
    );
  }
}

/// The one action a popup asks for: a lit gradient in its colour. No glow
/// spills from it: on this app a glow marks a state, not an action.
///
/// The label takes whichever of light or dark ink reads on [color], so a
/// light accent carries a dark label and a deep one a light label without
/// each caller choosing.
class InkFilledButton extends StatelessWidget {
  const InkFilledButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final Color color;

  /// Null disables the button; it dims rather than disappearing, so the row
  /// does not reflow while the action is under way.
  final VoidCallback? onPressed;

  /// A glyph before the label, drawn in the label's colour.
  final Widget? leading;

  static const _lift = 0.16;
  static const _pressAlpha = 0.10;
  static const _disabledAlpha = 0.45;
  static const _stateChange = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = AppPalette.labelOn(color);
    final radius = BorderRadius.circular(AppLayout.inkButtonRadius.r);

    return AnimatedOpacity(
      duration: _stateChange,
      opacity: enabled ? 1 : _disabledAlpha,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color.lerp(color, AppPalette.lift, _lift)!, color],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: ink.withValues(alpha: _pressAlpha),
            highlightColor: ink.withValues(alpha: _pressAlpha),
            child: SizedBox(
              height: AppLayout.inkButtonHeight.h,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.inkButtonPadH.w,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: ink,
                    size: AppLayout.inkButtonGlyph.sp,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        SizedBox(width: AppLayout.inkButtonGap.w),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: AppLayout.inkButtonLabel.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The quiet action beside [InkFilledButton]: a raised tile with a rim.
class InkQuietButton extends StatelessWidget {
  const InkQuietButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;

  /// Null disables it, while the action beside it is under way.
  final VoidCallback? onPressed;

  static const _disabledAlpha = 0.5;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppLayout.inkButtonRadius.r);

    return Opacity(
      opacity: onPressed == null ? _disabledAlpha : 1,
      child: Material(
        color: palette.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: AppLayout.inkButtonHeight.h,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: AppLayout.inkButtonLabel.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cancel beside the one action a popup asks for, the action twice as wide.
class InkDialogActions extends StatelessWidget {
  const InkDialogActions({
    super.key,
    required this.cancelLabel,
    required this.onCancel,
    required this.action,
  });

  final String cancelLabel;
  final VoidCallback? onCancel;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkQuietButton(label: cancelLabel, onPressed: onCancel),
        ),
        SizedBox(width: AppLayout.inkActionsGap.w),
        Expanded(flex: 2, child: action),
      ],
    );
  }
}

/// Two choices in one control, the chosen one raised on a sliding thumb.
class InkSegmented<T> extends StatelessWidget {
  const InkSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.accent,
  });

  /// Each choice, with its glyph and label.
  final List<({T value, IconData icon, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// The chosen segment's glyph.
  final Color accent;

  static const _swap = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final index = segments.indexWhere((s) => s.value == selected);
    final share = 1 / segments.length;
    final textDirection = Directionality.of(context);
    // From -1 at the first segment to 1 at the last, mirrored for a
    // right-to-left reader.
    final x = segments.length == 1
        ? 0.0
        : -1 + 2 * index / (segments.length - 1);

    return Container(
      padding: EdgeInsets.all(AppLayout.inkSegmentPad.w),
      decoration: BoxDecoration(
        color: palette.page,
        borderRadius: BorderRadius.circular(AppLayout.inkSegmentRadius.r),
        border: Border.all(color: palette.line),
      ),
      child: SizedBox(
        height: AppLayout.inkSegmentHeight.h,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(
                  textDirection == TextDirection.rtl ? -x : x,
                  0,
                ),
                duration: _swap,
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: share,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        AppLayout.inkSegmentThumbRadius.r,
                      ),
                      border: Border.all(color: palette.lineStrong),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  for (final segment in segments)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: segment.value == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(segment.value),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                segment.icon,
                                size: AppLayout.inkSegmentGlyph.sp,
                                color: segment.value == selected
                                    ? accent
                                    : palette.faint,
                              ),
                              SizedBox(width: AppLayout.inkSegmentGap.w),
                              Flexible(
                                child: Text(
                                  segment.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppLayout.inkSegmentLabel.sp,
                                    fontWeight: FontWeight.w500,
                                    color: segment.value == selected
                                        ? palette.text
                                        : palette.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

/// How a field in a popup is drawn: a dark well with a hairline rim that
/// takes [accent] while it has focus.
abstract final class InkInput {
  static const _focusAlpha = 0.55;

  static TextStyle text(AppPalette palette) =>
      TextStyle(color: palette.text, fontSize: AppLayout.inkFieldLabel.sp);

  static InputDecoration decoration(
    AppPalette palette, {
    required Color accent,
    String? hint,
    bool invalid = false,
    Widget? prefixIcon,
  }) {
    final radius = BorderRadius.circular(AppLayout.inkFieldRadius.r);
    OutlineInputBorder rim(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: palette.faint,
        fontSize: AppLayout.inkFieldLabel.sp,
      ),
      prefixIcon: prefixIcon,
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) =>
            states.contains(WidgetState.focused) ? accent : palette.faint,
      ),
      filled: true,
      fillColor: palette.page,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppLayout.inkFieldPadH.w,
        vertical: AppLayout.inkFieldPadV.h,
      ),
      border: rim(invalid ? palette.failedInk : palette.line),
      enabledBorder: rim(invalid ? palette.failedInk : palette.line),
      focusedBorder: rim(
        invalid ? palette.failedInk : accent.withValues(alpha: _focusAlpha),
      ),
    );
  }
}
