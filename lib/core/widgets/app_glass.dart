import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Frosted-glass look shared across modules — gradient fill, optional rim.
///
/// Dialogs and sheets are opaque: text has to stay legible over a scrim or a
/// scrolling list. In-place panels stay translucent.
///
/// Every style is drawn in the [AppPalette] it is handed, so a caller passes
/// the one its context reads.
abstract final class AppGlass {
  /// The hairline every glass shape is rimmed with.
  static const _rimWidth = 1.0;

  /// A dialog sits above everything, so it casts the deeper shadow; a panel
  /// rests on the page and only needs to lift off it.
  static const _dialogShadowAlpha = 0.30;
  static const _dialogShadowBlur = 20.0;
  static const _dialogShadowDrop = 8.0;

  static const _panelShadowAlpha = 0.18;
  static const _panelShadowBlur = 16.0;
  static const _panelShadowDrop = 6.0;

  /// A card on the page: an opaque ink surface with a hairline rim.
  static AppGlassStyle panel(
    AppPalette palette, {
    required double cornerRadius,
    Color? color,
  }) => AppGlassStyle(
    cornerRadius: cornerRadius,
    color: color ?? palette.surface,
    borderColor: palette.line,
    borderWidth: _rimWidth,
  );

  /// A small shape raised on a card: a glyph's tile, a pill.
  static AppGlassStyle chip(
    AppPalette palette, {
    required double cornerRadius,
    Color? color,
  }) => AppGlassStyle(
    cornerRadius: cornerRadius,
    color: color ?? palette.surfaceRaised,
  );

  static AppGlassStyle dialog(
    AppPalette palette, {
    required double cornerRadius,
  }) => AppGlassStyle(
    cornerRadius: cornerRadius,
    color: palette.dialog,
    borderColor: palette.lineStrong,
    borderWidth: _rimWidth,
    boxShadow: [
      BoxShadow(
        color: palette.shadow.withValues(alpha: _dialogShadowAlpha),
        blurRadius: _dialogShadowBlur,
        offset: const Offset(0, _dialogShadowDrop),
      ),
    ],
  );

  /// What a panel resting on the page casts.
  static BoxShadow _panelShadow(AppPalette palette) => BoxShadow(
    color: palette.shadow.withValues(alpha: _panelShadowAlpha),
    blurRadius: _panelShadowBlur,
    offset: const Offset(0, _panelShadowDrop),
  );

  /// Home server row and IP reading — an ink card with a status-coloured rim.
  static AppGlassStyle homeSurface(
    AppPalette palette, {
    required double cornerRadius,
    required Color borderColor,
  }) => AppGlassStyle(
    cornerRadius: cornerRadius,
    color: palette.surface,
    borderColor: borderColor,
    borderWidth: _rimWidth,
    boxShadow: [_panelShadow(palette)],
  );

  /// The home dial: the rim and the shadow of a [homeSurface], cut round,
  /// with [glow] round it while the dial has a status to report.
  ///
  /// Its disc is drawn in [tintStops], the dial's own light, rather than
  /// filmed in white: white the size of the dial greys out the saturated
  /// page under it, khaki in one status and brown in another. The caller
  /// decides how the light is laid on, since that differs by theme.
  static AppGlassStyle dial(
    AppPalette palette, {
    required List<Color> tintStops,
    required Color borderColor,
    BoxShadow? glow,
  }) => AppGlassStyle(
    shape: BoxShape.circle,
    gradientColors: tintStops,
    borderColor: borderColor,
    borderWidth: _rimWidth,
    boxShadow: [_panelShadow(palette), ?glow],
  );
}

/// Parameters for an [AppGlassPanel].
class AppGlassStyle {
  const AppGlassStyle({
    this.cornerRadius = 0,
    this.color,
    this.gradientColors,
    this.borderColor,
    this.borderWidth = 0,
    this.boxShadow,
    this.shape = BoxShape.rectangle,
  });

  final double cornerRadius;
  final Color? color;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final BoxShape shape;
}

/// A frosted panel sized by [child].
class AppGlassPanel extends StatelessWidget {
  const AppGlassPanel({super.key, required this.style, required this.child});

  final AppGlassStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = style.shape == BoxShape.circle
        ? null
        : BorderRadius.circular(style.cornerRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: style.shape,
        borderRadius: radius,
        color: style.gradientColors == null ? style.color : null,
        gradient: style.gradientColors == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: style.gradientColors!,
              ),
        border: style.borderWidth > 0 && style.borderColor != null
            ? Border.all(color: style.borderColor!, width: style.borderWidth)
            : null,
        boxShadow: style.boxShadow,
      ),
      child: child,
    );
  }
}
