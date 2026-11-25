import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/widgets/theme_mode_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _designSize = Size(393, 852);

/// The three choices, spelled out rather than read back from the
/// localizations under test.
const _system = 'System default';
const _light = 'Light';
const _dark = 'Dark';

/// Light, as the Persian app names it.
const _lightInPersian = 'روشن';

void main() {
  /// Mounts the dropdown on a phone-sized screen, in [locale], and returns
  /// every choice it reports as picked.
  Future<List<ThemeMode>> pumpDropdown(
    WidgetTester tester, {
    ThemeMode selected = ThemeMode.system,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final picked = <ThemeMode>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          locale: locale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ThemeModeDropdown(
                selected: selected,
                onSelected: picked.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(ThemeModeDropdown));
    await tester.pumpAndSettle();
  }

  Finder inMenu(String label) => find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(label),
  );

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  group('ThemeModeDropdown', () {
    testWidgets('should show System default when nothing is chosen', (
      tester,
    ) async {
      await pumpDropdown(tester);

      expect(field(tester).controller.text, _system);
    });

    // The choices are translated, unlike the languages, so the same choice
    // is named anew when the language changes under it.
    testWidgets('should rename the chosen one when the language changes', (
      tester,
    ) async {
      await pumpDropdown(tester, selected: ThemeMode.light);
      await pumpDropdown(
        tester,
        selected: ThemeMode.light,
        locale: const Locale('fa'),
      );

      expect(field(tester).controller.text, _lightInPersian);
    });

    testWidgets('should list the three choices', (tester) async {
      await pumpDropdown(tester);
      await openMenu(tester);

      for (final label in [_system, _light, _dark]) {
        expect(inMenu(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('should tick the selected choice and no other', (tester) async {
      await pumpDropdown(tester, selected: ThemeMode.light);
      await openMenu(tester);

      final tick = find.byIcon(Iconsax.tick_circle_copy);
      expect(tick, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: tick, matching: find.byType(MenuItemButton)),
          matching: find.text(_light),
        ),
        findsOneWidget,
      );
    });

    testWidgets('should mark each choice with its own icon', (tester) async {
      await pumpDropdown(tester);
      await openMenu(tester);

      final icons = {
        _system: Iconsax.mobile_copy,
        _light: Iconsax.sun_1_copy,
        _dark: Iconsax.moon_copy,
      };
      for (final MapEntry(key: label, value: icon) in icons.entries) {
        expect(
          find.descendant(
            of: find.ancestor(
              of: inMenu(label),
              matching: find.byType(MenuItemButton),
            ),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
          reason: label,
        );
      }
    });

    // The moon now names Dark in the menu, so the row it opens from needs an
    // icon of its own, or Theme and Dark would read as the same thing.
    testWidgets('should head the row with an icon none of its choices use', (
      tester,
    ) async {
      await pumpDropdown(tester);

      expect(
        find.descendant(
          of: find.byType(ThemeModeDropdown),
          matching: find.byIcon(Iconsax.colorfilter_copy),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Iconsax.moon_copy), findsNothing);
    });

    testWidgets('should report the picked choice', (tester) async {
      final picked = await pumpDropdown(tester);
      await openMenu(tester);

      await tester.tap(inMenu(_dark));
      await tester.pumpAndSettle();

      expect(picked, [ThemeMode.dark]);
    });
  });
}
