import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_servers_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _themes = <String, AppPalette>{
  'dark': AppPalette.dark,
  'light': AppPalette.light,
};

ThemeData _themeFor(AppPalette palette) => palette == AppPalette.light
    ? AppTheme.light(fontFamily: 'Roboto')
    : AppTheme.dark(fontFamily: 'Roboto');

Widget _headerUnderTest({
  required AppPalette palette,
  required bool isConnected,
}) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: _themeFor(palette),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PremiumServersHeader(
            state: const PremiumServersState(hasLoaded: true),
            isConnected: isConnected,
            isBusy: false,
          ),
        ),
      ),
    ),
  );
}

/// The glass the header's one control is drawn on.
AppGlassStyle _controlGlass(WidgetTester tester, String control) {
  return tester
      .widget<AppGlassPanel>(
        find.descendant(
          of: find.byKey(ValueKey(control)),
          matching: find.byType(AppGlassPanel),
        ),
      )
      .style;
}

void main() {
  group('PremiumServersHeader', () {
    for (final theme in _themes.entries) {
      final palette = theme.value;

      testWidgets(
        'should draw disconnect on the same chip as refresh in ${theme.key}',
        (tester) async {
          await tester.pumpWidget(
            _headerUnderTest(palette: palette, isConnected: false),
          );
          final refresh = _controlGlass(tester, 'refresh');

          await tester.pumpWidget(
            _headerUnderTest(palette: palette, isConnected: true),
          );
          await tester.pumpAndSettle();
          final disconnect = _controlGlass(tester, 'disconnect');

          expect(disconnect.color, refresh.color);
          expect(disconnect.cornerRadius, refresh.cornerRadius);
        },
      );

      testWidgets(
        'should paint only the disconnect glyph in the failure ink in '
        '${theme.key}',
        (tester) async {
          await tester.pumpWidget(
            _headerUnderTest(palette: palette, isConnected: true),
          );
          final control = find.byKey(const ValueKey('disconnect'));

          final glyph = tester.widget<Icon>(
            find.descendant(of: control, matching: find.byType(Icon)),
          );
          final label = tester.widget<Text>(
            find.descendant(of: control, matching: find.byType(Text)),
          );

          expect(glyph.icon, Iconsax.shield_cross_copy);
          expect(glyph.color, palette.failedInk);
          expect(label.style?.color, palette.text);
        },
      );

      testWidgets(
        'should write the connected hint in the accent in ${theme.key}',
        (tester) async {
          await tester.pumpWidget(
            _headerUnderTest(palette: palette, isConnected: true),
          );

          final hint = tester.widgetList<Text>(find.byType(Text)).elementAt(1);

          expect(hint.style?.color, palette.accent);
        },
      );
    }
  });
}
