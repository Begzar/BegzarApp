import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The one action the account tab is asking for: signing in, creating the
/// account, buying or renewing.
///
/// Drawn as a lit gradient in the account's accent rather than a flat fill, so
/// it is the brightest thing on the tab and the eye lands on it first. No glow
/// spills from it: on this app a glow marks a state, like the dial's
/// connection, rather than an action. A disabled button dims instead, so a
/// sign-in in flight reads as waiting rather than as offered.
class PremiumPrimaryButton extends StatelessWidget {
  const PremiumPrimaryButton({
    super.key,
    required this.label,
    required this.accent,
    required this.onPressed,
    this.leading,
    this.compact = false,
  });

  final String label;
  final PremiumAccent accent;

  /// Null disables the button; the fill dims rather than disappearing, so the
  /// control keeps its place while a sign-in is in flight.
  final VoidCallback? onPressed;

  /// A glyph before the label, drawn in the label's colour: where a purchase
  /// will open, say.
  final Widget? leading;

  /// The shorter button that sits inside the pass.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppLayout.premiumCtaRadius.r);
    final glyph = AppLayout.premiumCtaGlyph.sp;

    return AnimatedOpacity(
      duration: PremiumPalette.stateChange,
      opacity: enabled ? 1 : PremiumPalette.disabledAlpha,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [accent.primary, accent.secondary],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: accent.onPrimary.withValues(
              alpha: PremiumPalette.pressAlpha,
            ),
            highlightColor: accent.onPrimary.withValues(
              alpha: PremiumPalette.pressAlpha,
            ),
            child: SizedBox(
              height: compact
                  ? AppLayout.premiumCtaCompactHeight.h
                  : AppLayout.premiumCtaHeight.h,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.buttonPadH.w,
                ),
                child: IconTheme(
                  data: IconThemeData(color: accent.onPrimary, size: glyph),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        SizedBox(width: AppLayout.premiumCtaGap.w),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact
                                ? AppLayout.premiumCtaCompactLabel.sp
                                : AppLayout.premiumCtaLabel.sp,
                            fontWeight: FontWeight.w600,
                            color: accent.onPrimary,
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

/// A supporting action — a quiet filled tile, so several can sit side by side
/// without competing with each other or with the primary.
///
/// The label stays light and only a destructive action's glyph takes a
/// colour, which is what lets Refresh and Sign out sit in one row: they are
/// told apart by their icons, and neither shouts.
class PremiumSecondaryButton extends StatelessWidget {
  const PremiumSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Swaps the icon for a spinner in place, so the row does not reflow while
  /// the action runs.
  final bool isLoading;

  /// Draws the glyph in the destructive colour.
  ///
  /// For actions that take something away, which here means signing out.
  /// Signing out ends the session and hands the seat back, and the account
  /// has a limited number of those.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final tone = isDestructive ? palette.danger : palette.inkText;
    final dimmed = onPressed == null && !isLoading;
    final radius = BorderRadius.circular(AppLayout.premiumActionRadius.r);
    final glyph = AppLayout.premiumActionGlyph.sp;

    return AnimatedOpacity(
      duration: PremiumPalette.stateChange,
      opacity: dimmed ? PremiumPalette.dimmedAlpha : 1,
      child: Material(
        color: palette.inkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: palette.inkLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: AppLayout.premiumActionHeight.h,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppLayout.premiumActionGap.w,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox.square(
                      dimension: glyph,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tone,
                      ),
                    )
                  else
                    Icon(icon, size: glyph, color: tone),
                  SizedBox(width: AppLayout.premiumActionGap.w),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.premiumActionLabel.sp,
                        fontWeight: FontWeight.w500,
                        color: palette.inkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A form's title and the line under it, over both halves of the tab.
class PremiumFormHeading extends StatelessWidget {
  const PremiumFormHeading({
    super.key,
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: displayFamilyOf(context),
            fontSize: AppLayout.premiumHeading.sp,
            fontWeight: FontWeight.w600,
            height: AppLayout.premiumHeadingLineHeight,
            letterSpacing: AppLayout.premiumHeadingTracking,
            color: palette.inkText,
          ),
        ),
        SizedBox(height: AppLayout.premiumHeadingGap.h),
        Text(
          hint,
          style: TextStyle(
            fontSize: AppLayout.premiumSub.sp,
            height: AppLayout.premiumSubLineHeight,
            color: palette.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// A quiet action under a form — resending a code, the privacy policy. Text
/// only, so it never competes with the primary button above it.
class PremiumTextLink extends StatelessWidget {
  const PremiumTextLink({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.opensPage = false,
  });

  final String label;
  final Color color;

  /// Null disables the link, for a resend that is still waiting.
  final VoidCallback? onPressed;

  /// Underlined, for a link that leaves the app for a page. A muted line of
  /// text is otherwise not something anyone thinks to tap.
  final bool opensPage;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: palette.textSecondary,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppLayout.textBase.sp,
          fontWeight: FontWeight.w600,
          decoration: opensPage ? TextDecoration.underline : null,
          decorationColor: color,
        ),
      ),
    );
  }
}

/// The eye that shows or hides a password, sized for [PremiumTextField].
class PremiumPasswordEye extends StatelessWidget {
  const PremiumPasswordEye({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final box = AppLayout.premiumFieldEye.w;

    return Padding(
      padding: EdgeInsetsDirectional.only(end: AppLayout.premiumFieldPadEnd.w),
      child: SizedBox.square(
        dimension: box,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(
            obscured ? Iconsax.eye_slash : Iconsax.eye,
            color: palette.inkFaint,
            size: AppLayout.premiumFieldEyeGlyph.sp,
          ),
        ),
      ),
    );
  }
}

/// A field on the account tab: a dark well with its glyph at the start and
/// the placeholder inside it.
///
/// The glyph and the rim take the accent while the field has focus, and the
/// well lifts a step, so the one being typed into is plain at a glance.
class PremiumTextField extends StatelessWidget {
  const PremiumTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.accent,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
    this.autofillHints,
    this.errorText,
    this.textDirection,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final PremiumAccent accent;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  /// What is wrong with this field, shown under it.
  final String? errorText;

  /// Left to right for an address or a code, which reads the same in every
  /// locale and would be reordered by a right-to-left one.
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final radius = BorderRadius.circular(AppLayout.premiumFieldRadius.r);

    OutlineInputBorder rim(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: color,
        width: AppLayout.premiumFieldFocusRim,
      ),
    );

    final focusRim = accent.primary.withValues(
      alpha: PremiumPalette.fieldFocusAlpha,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textDirection: textDirection,
      cursorColor: accent.primary,
      style: TextStyle(
        color: palette.inkText,
        fontSize: AppLayout.premiumFieldLabel.sp,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: palette.inkFaint,
          fontSize: AppLayout.premiumFieldLabel.sp,
        ),
        prefixIcon: Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppLayout.premiumFieldPadStart.w,
            end: AppLayout.premiumFieldIconGap.w,
          ),
          child: Icon(icon, size: AppLayout.premiumFieldGlyph.sp),
        ),
        prefixIconConstraints: const BoxConstraints(),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.error)
              ? palette.danger
              : states.contains(WidgetState.focused)
              ? accent.primary
              : palette.inkFaint,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(),
        errorText: errorText,
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? palette.inkSurfaceRaised
              : palette.inkSurface,
        ),
        contentPadding: EdgeInsetsDirectional.only(
          top: AppLayout.premiumFieldPadV.h,
          bottom: AppLayout.premiumFieldPadV.h,
          end: AppLayout.premiumFieldPadEnd.w,
        ),
        border: rim(palette.inkLine),
        enabledBorder: rim(palette.inkLine),
        focusedBorder: rim(focusRim),
        errorStyle: TextStyle(color: palette.danger),
        errorBorder: rim(palette.danger),
        focusedErrorBorder: rim(palette.danger),
      ),
    );
  }
}
