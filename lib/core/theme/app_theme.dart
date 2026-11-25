import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// The two [ThemeData]s the app runs on, one per [AppPalette].
///
/// They live here rather than inside the shell widget that used to build them
/// so a test can assert what they hand Material — the snackbar's ink above
/// all, which nothing in the widget tree states and every snack inherits.
abstract final class AppTheme {
  /// Snackbars, which Material otherwise paints from its own colour scheme.
  ///
  /// Left to the default, content ink is `onInverseSurface` — a dark tone,
  /// because the inverse of a dark scheme is a light surface. Every snack in
  /// this app states its own surface and none of them stated the ink, so the
  /// account screen's "device removed" message read near-black on a dark
  /// slate. The ink is named here, once, so no snack raised anywhere can
  /// inherit that again.
  ///
  /// The surface is named for the same reason from the other side: a snack
  /// that sets no colour of its own would take Material's default and stand
  /// out of the app. The two that carry an outcome still override it with the
  /// success and failure tones.
  static SnackBarThemeData _snackBarTheme(
    AppPalette palette,
    TextStyle baseStyle,
  ) {
    return SnackBarThemeData(
      backgroundColor: palette.snack,
      contentTextStyle: baseStyle.copyWith(color: palette.onSnack),
      behavior: SnackBarBehavior.floating,
    );
  }

  /// What both themes share, drawn in [palette] over [colorScheme].
  static ThemeData _themed(
    AppPalette palette,
    ColorScheme colorScheme, {
    required String fontFamily,
  }) {
    final baseStyle = TextStyle(color: palette.text, fontFamily: fontFamily);

    return ThemeData(
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      extensions: [palette],
      snackBarTheme: _snackBarTheme(palette, baseStyle),
      textTheme: TextTheme(
        titleMedium: baseStyle.apply(color: palette.muted),
        bodyMedium: baseStyle,
        labelLarge: baseStyle,
        bodySmall: baseStyle.apply(color: palette.muted),
        titleLarge: baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: AppLayout.text4xl,
        ),
      ),
    );
  }

  static ThemeData dark({required String fontFamily}) {
    const palette = AppPalette.dark;
    return _themed(
      palette,
      ColorScheme.dark(
        primary: palette.schemePrimary,
        secondary: palette.schemeSecondary,
        onSecondary: palette.veil,
      ),
      fontFamily: fontFamily,
    );
  }

  static ThemeData light({required String fontFamily}) {
    const palette = AppPalette.light;
    return _themed(
      palette,
      ColorScheme.light(
        primary: palette.schemePrimary,
        secondary: palette.schemeSecondary,
        onSecondary: palette.veil,
      ),
      fontFamily: fontFamily,
    );
  }

  /// The theme for [brightness], for a subtree that has to be drawn in the
  /// theme the app is in rather than in the one it was built with.
  static ThemeData forBrightness(
    Brightness brightness, {
    required String fontFamily,
  }) => switch (brightness) {
    Brightness.dark => dark(fontFamily: fontFamily),
    Brightness.light => light(fontFamily: fontFamily),
  };
}
