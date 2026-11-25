import 'dart:math' as math;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/widgets/language_dropdown.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _designSize = Size(393, 852);

/// The face each language is set in, spelled out rather than read back from
/// the helper under test, so a language that lost its face fails rather than
/// agreeing with itself.
const _fonts = {
  AppLanguage.english: 'Geist',
  AppLanguage.persian: 'Estedad',
  AppLanguage.chinese: 'Poppins',
  AppLanguage.russian: 'Poppins',
};

void main() {
  /// Mounts the dropdown on a phone-sized screen, and returns every language
  /// it reports as picked.
  ///
  /// [platform] matters because Material lets a desktop type into a dropdown
  /// field by default and a phone not.
  Future<List<AppLanguage>> pumpDropdown(
    WidgetTester tester, {
    AppLanguage? selected = AppLanguage.english,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final picked = <AppLanguage>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
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
              child: LanguageDropdown(
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
    await tester.tap(find.byType(LanguageDropdown));
    await tester.pumpAndSettle();
  }

  Finder inMenu(String label) => find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(label),
  );

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  /// How far from the left of the screen the ink of a menu label begins —
  /// the glyphs, not the box, which spans the row whichever way the text sits.
  double inkLeft(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: inMenu(label), matching: find.byType(RichText)),
    );
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    final left = boxes.map((box) => box.left).reduce(math.min);
    return paragraph.localToGlobal(Offset(left, 0)).dx;
  }

  group('LanguageDropdown', () {
    testWidgets('shows the selected language in its own face', (tester) async {
      await pumpDropdown(tester, selected: AppLanguage.persian);

      expect(field(tester).controller.text, 'فارسی');
      expect(field(tester).style.fontFamily, 'Estedad');
    });

    testWidgets('sets its text as far from the tile as a settings row does', (
      tester,
    ) async {
      await pumpDropdown(tester);

      final gap =
          tester.getTopLeft(find.byType(EditableText)).dx -
          tester.getTopRight(find.byType(SettingsTileIcon)).dx;
      expect(gap, closeTo(AppLayout.settingsTileIconGap, 0.5));
    });

    testWidgets('follows a selection its parent changes', (tester) async {
      await pumpDropdown(tester, selected: AppLanguage.persian);
      await pumpDropdown(tester, selected: AppLanguage.russian);

      expect(field(tester).controller.text, 'Русский');
      expect(field(tester).style.fontFamily, 'Poppins');
    });

    testWidgets('lists every language, each in its own face', (tester) async {
      await pumpDropdown(tester);
      await openMenu(tester);

      for (final language in AppLanguage.values) {
        final label = tester.widget<Text>(inMenu(language.nativeLabel));
        expect(
          label.style?.fontFamily,
          _fonts[language],
          reason: language.code,
        );
      }
    });

    testWidgets('starts every language on the same edge, whichever way it '
        'is written', (tester) async {
      await pumpDropdown(tester);
      await openMenu(tester);

      final english = inkLeft(tester, 'English');
      for (final label in ['فارسی', '中文', 'Русский']) {
        expect(inkLeft(tester, label), closeTo(english, 1), reason: label);
      }
    });

    testWidgets('ticks the selected language and no other', (tester) async {
      await pumpDropdown(tester, selected: AppLanguage.chinese);
      await openMenu(tester);

      final tick = find.byIcon(Iconsax.tick_circle_copy);
      expect(tick, findsOneWidget);
      expect(
        find.ancestor(of: tick, matching: find.byType(MenuItemButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: tick, matching: find.byType(MenuItemButton)),
          matching: find.text('中文'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reports the language picked from the menu', (tester) async {
      final picked = await pumpDropdown(tester);
      await openMenu(tester);

      await tester.tap(inMenu('Русский'));
      await tester.pumpAndSettle();

      expect(picked, [AppLanguage.russian]);
    });

    testWidgets('cannot be typed into, even on a desktop', (tester) async {
      await pumpDropdown(tester, platform: TargetPlatform.windows);
      await openMenu(tester);

      expect(field(tester).readOnly, isTrue);
    });
  });
}
