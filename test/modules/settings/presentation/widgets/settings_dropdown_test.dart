import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _designSize = Size(393, 852);
const _choices = ['One', 'Two', 'Three'];

/// The palette a bare test app is drawn in: the dark one.
const _palette = SettingsPalette(AppPalette.dark);

/// The icon each choice is marked with, when the dropdown is given icons.
const _icons = {
  'One': Iconsax.mobile_copy,
  'Two': Iconsax.sun_1_copy,
  'Three': Iconsax.moon_copy,
};

Future<void> _pumpDropdown(
  WidgetTester tester, {
  bool withIcons = false,
}) async {
  tester.view.physicalSize = _designSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: SettingsDropdown<String>(
            icon: Iconsax.moon_copy,
            label: 'Pick',
            selected: _choices.first,
            choices: _choices,
            labelOf: (choice) => choice,
            iconOf: withIcons ? (choice) => _icons[choice]! : null,
            onSelected: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DropdownMenu<String> _menu(WidgetTester tester) =>
    tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));

DropdownMenuEntry<String> _entry(WidgetTester tester, String choice) => _menu(
  tester,
).dropdownMenuEntries.firstWhere((entry) => entry.value == choice);

void main() {
  group('SettingsDropdown', () {
    // Every other surface on the settings screen is an ink card with a
    // hairline rim; Material's default sheet was the one bare white slab.
    testWidgets('should draw its menu as a settings card', (tester) async {
      await _pumpDropdown(tester);

      final style = _menu(tester).menuStyle!;
      expect(style.backgroundColor!.resolve({}), _palette.menuSurface);
      expect(style.surfaceTintColor!.resolve({}), Colors.transparent);
      expect(style.side!.resolve({})!.color, _palette.border);
    });

    testWidgets('should float its menu clear of the row it opens from', (
      tester,
    ) async {
      await _pumpDropdown(tester);

      expect(_menu(tester).alignmentOffset!.dy, AppLayout.settingsMenuGap.h);
    });

    // The chosen row is marked the way the app marks a selected thing: a
    // tint of the accent, with its label and tick in the accent.
    testWidgets('should tint the chosen entry in the accent', (tester) async {
      await _pumpDropdown(tester);

      final chosen = _entry(tester, 'One');
      final other = _entry(tester, 'Two');
      expect(chosen.style!.backgroundColor!.resolve({}), _palette.selectedRow);
      expect(other.style!.backgroundColor!.resolve({}), Colors.transparent);
      expect((chosen.labelWidget! as Text).style!.color, _palette.accent);
      expect((other.labelWidget! as Text).style!.color, _palette.textPrimary);
    });

    // The menu continues the row it opens from: its labels start where the
    // field's text does, past the row's icon, not at the card's edge.
    testWidgets('should line its labels up under the field\'s text', (
      tester,
    ) async {
      await _pumpDropdown(tester);
      final field = tester.getTopLeft(find.byType(EditableText)).dx;

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Two').last).dx, closeTo(field, 1));
    });

    // With icons the menu reads as rows hanging off the one it opens from:
    // each icon under the row's icon, each label under the row's text.
    testWidgets('should line icons and labels up with the row', (tester) async {
      await _pumpDropdown(tester, withIcons: true);
      final rowIcon = tester.getTopLeft(find.byIcon(Iconsax.moon_copy)).dx;
      final field = tester.getTopLeft(find.byType(EditableText)).dx;

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();

      final entryIcon = find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.byIcon(Iconsax.sun_1_copy),
      );
      expect(tester.getTopLeft(entryIcon).dx, closeTo(rowIcon, 1));
      expect(tester.getTopLeft(find.text('Two').last).dx, closeTo(field, 1));
    });

    testWidgets('should draw the chosen entry\'s icon in the accent', (
      tester,
    ) async {
      await _pumpDropdown(tester, withIcons: true);
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();

      Color? iconColour(IconData icon) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byType(MenuItemButton),
              matching: find.byIcon(icon),
            ),
          )
          .color;
      expect(iconColour(Iconsax.mobile_copy), _palette.accent);
      expect(iconColour(Iconsax.sun_1_copy), _palette.icon);
    });

    // Material's own highlight is a flat grey that belongs to no palette.
    testWidgets('should answer a press and a focus in the accent', (
      tester,
    ) async {
      await _pumpDropdown(tester);

      final overlay = _entry(tester, 'Two').style!.overlayColor!;
      expect(overlay.resolve({WidgetState.pressed}), _palette.menuPress);
      expect(overlay.resolve({WidgetState.focused}), _palette.menuPress);
      expect(overlay.resolve({WidgetState.hovered}), _palette.menuPress);
    });
  });
}
