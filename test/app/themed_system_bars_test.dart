import 'package:begzar/app/themed_system_bars.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The style the bars are asked for under [theme].
Future<SystemUiOverlayStyle> _askedFor(
  WidgetTester tester,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) =>
          ThemedSystemBars(child: child ?? const SizedBox.shrink()),
      home: const SizedBox.shrink(),
    ),
  );

  return tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      )
      .value;
}

void main() {
  group('ThemedSystemBars', () {
    testWidgets('should ask for dark icons in a light theme', (tester) async {
      final style = await _askedFor(
        tester,
        AppTheme.light(fontFamily: 'Roboto'),
      );

      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });

    testWidgets('should ask for light icons in a dark theme', (tester) async {
      final style = await _askedFor(
        tester,
        AppTheme.dark(fontFamily: 'Roboto'),
      );

      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
    });

    // Material's two presets both carry a black navigation bar with light
    // icons, which on Android 14 and older sat under every light page.
    testWidgets('should ask for a clear navigation bar with dark icons in a '
        'light theme', (tester) async {
      final style = await _askedFor(
        tester,
        AppTheme.light(fontFamily: 'Roboto'),
      );

      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('should ask for light navigation icons in a dark theme', (
      tester,
    ) async {
      final style = await _askedFor(
        tester,
        AppTheme.dark(fontFamily: 'Roboto'),
      );

      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('should keep the status bar clear', (tester) async {
      final style = await _askedFor(
        tester,
        AppTheme.light(fontFamily: 'Roboto'),
      );

      expect(style.statusBarColor, Colors.transparent);
    });
  });
}
