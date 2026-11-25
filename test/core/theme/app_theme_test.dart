import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a snackbar inherits.
///
/// Material paints snack content in `onInverseSurface`, which on a dark scheme
/// is a dark tone — and every snack in this app sets its own dark surface and
/// none of them set the ink. The account screen's "device removed" message was
/// dark-on-dark for exactly that reason, so the ink is asserted here on the
/// rendered snack rather than on the theme field that produces it.
void main() {
  const removedMessage = 'Device removed successfully';
  final successSurface = AppPalette.dark.snack;

  Widget snackHost({Color? backgroundColor}) => MaterialApp(
    theme: AppTheme.dark(fontFamily: 'Roboto'),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(removedMessage),
              backgroundColor: backgroundColor,
            ),
          ),
          child: const Text('show'),
        ),
      ),
    ),
  );

  Future<TextStyle> shownSnackStyle(
    WidgetTester tester, {
    Color? backgroundColor,
  }) async {
    await tester.pumpWidget(snackHost(backgroundColor: backgroundColor));
    await tester.tap(find.text('show'));
    await tester.pump();

    return DefaultTextStyle.of(tester.element(find.text(removedMessage))).style;
  }

  group('snackbar ink', () {
    testWidgets(
      'should read in the primary text colour over a success surface',
      (tester) async {
        final style = await shownSnackStyle(
          tester,
          backgroundColor: successSurface,
        );

        expect(style.color, AppPalette.dark.onSnack);
      },
    );

    testWidgets('should read in the primary text colour on a plain snack', (
      tester,
    ) async {
      final style = await shownSnackStyle(tester);

      expect(style.color, AppPalette.dark.onSnack);
    });
  });

  // A snack that names no colour of its own would otherwise take Material's
  // light default and stand out of a dark app.
  testWidgets('should give a snack with no colour an opaque dark surface', (
    tester,
  ) async {
    await tester.pumpWidget(snackHost());
    await tester.tap(find.text('show'));
    await tester.pump();

    final snackBar = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(snackBar.color, AppPalette.dark.dialog);
  });

  group('AppTheme.dark', () {
    test('should carry the dark palette', () {
      final theme = AppTheme.dark(fontFamily: 'Roboto');

      expect(theme.extension<AppPalette>(), same(AppPalette.dark));
    });
  });

  group('AppTheme.light', () {
    test('should carry the light palette', () {
      final theme = AppTheme.light(fontFamily: 'Roboto');

      expect(theme.brightness, Brightness.light);
      expect(theme.extension<AppPalette>(), same(AppPalette.light));
    });

    test('should give snacks the inverse surface and its ink', () {
      final theme = AppTheme.light(fontFamily: 'Roboto');

      expect(theme.snackBarTheme.backgroundColor, AppPalette.light.snack);
      expect(
        theme.snackBarTheme.contentTextStyle?.color,
        AppPalette.light.onSnack,
      );
    });
  });

  group('AppTheme.forBrightness', () {
    test('should pick the theme for each brightness', () {
      expect(
        AppTheme.forBrightness(
          Brightness.light,
          fontFamily: 'Roboto',
        ).extension<AppPalette>(),
        same(AppPalette.light),
      );
      expect(
        AppTheme.forBrightness(
          Brightness.dark,
          fontFamily: 'Roboto',
        ).extension<AppPalette>(),
        same(AppPalette.dark),
      );
    });
  });
}
