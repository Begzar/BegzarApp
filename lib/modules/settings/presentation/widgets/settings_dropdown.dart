import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// A settings row that picks one of a few [choices] from a menu.
///
/// Material's own dropdown rather than a dialog of the module's making, so it
/// opens, closes and answers the keyboard the way the platform's menus do.
/// The field is drawn as a settings row, borderless, so it sits in a settings
/// card like any other row, and the chosen entry carries a tick in the menu.
class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.choices,
    required this.labelOf,
    required this.onSelected,
    this.localeOf,
    this.iconOf,
  });

  final IconData icon;
  final String label;

  /// Null leaves the field empty, for a value none of [choices] stands for.
  final T? selected;
  final List<T> choices;
  final String Function(T choice) labelOf;
  final ValueChanged<T> onSelected;

  /// The language a choice's label is written in, for labels that are not in
  /// the app's. Each is then set in that language's face, in the menu and in
  /// the field alike. Null sets every label in the app's own.
  final Locale Function(T choice)? localeOf;

  /// The icon a choice is marked with in the menu, in a tile like the row's,
  /// so the menu reads as rows hanging off the one it opens from. Null leaves
  /// the menu to its labels.
  final IconData Function(T choice)? iconOf;

  /// The gap `DropdownMenu` adds before every entry's label (its
  /// `_kInputStartGap`, in logical pixels), to line the label up with the
  /// field's text. An entry carrying its icon in the label starts that much
  /// further back, so the icon lands under the row's icon.
  static const _materialMenuLabelGap = 4.0;

  /// The gap Material puts between a field's leading icon and its text — the
  /// Material 3 `prefixToInputGap` in `InputDecorator`, in logical pixels —
  /// which the field's own padding does not reach. The tile's padding gives
  /// the rest of a settings row's gap.
  static const _materialIconToTextGap = 4.0;

  /// The row's inset before its icon, and after it up to Material's own gap.
  EdgeInsetsDirectional get _iconPadding => EdgeInsetsDirectional.only(
    start: AppLayout.settingsTilePadH.w,
    end: AppLayout.settingsTileIconGap.w - _materialIconToTextGap,
  );

  /// How wide the field's leading icon is, padding included.
  ///
  /// Material starts each menu label this far in, then adds the same gap it
  /// puts after the icon, so the labels line up under the field's text. It
  /// does so by itself only for an entry with no style of its own, and every
  /// entry here has one, so the width is handed over here instead.
  double get _leadingWidth =>
      _iconPadding.start + AppLayout.settingsTileIconSize.w + _iconPadding.end;

  String? _fontFamilyOf(T? choice) {
    final localeOf = this.localeOf;
    if (choice == null || localeOf == null) return null;
    return appFontFamilyFor(localeOf(choice));
  }

  /// A choice's label, after its icon when the menu has icons.
  Widget _entryLabel(SettingsPalette palette, T choice, bool chosen) {
    // No direction of its own: the menu's decides which edge every label
    // starts from, so they line up, and each word still runs its own way.
    final text = Text(
      labelOf(choice),
      locale: localeOf?.call(choice),
      style: TextStyle(
        color: chosen ? palette.accent : palette.textPrimary,
        fontFamily: _fontFamilyOf(choice),
        fontSize: AppLayout.textXl.sp,
        fontWeight: chosen ? FontWeight.w500 : FontWeight.w400,
      ),
    );
    final iconOf = this.iconOf;
    if (iconOf == null) return text;

    return Row(
      children: [
        SettingsTileIcon(
          icon: iconOf(choice),
          color: chosen ? palette.accent : null,
        ),
        SizedBox(width: AppLayout.settingsTileIconGap.w),
        Flexible(child: text),
      ],
    );
  }

  DropdownMenuEntry<T> _entry(SettingsPalette palette, T choice) {
    final chosen = choice == selected;
    return DropdownMenuEntry(
      value: choice,
      label: labelOf(choice),
      // A settings row's padding, the chosen row tinted the way a selected
      // row is everywhere in settings, and the accent rather than Material's
      // grey for a row pressed, hovered or reached by the keyboard.
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          chosen ? palette.selectedRow : Colors.transparent,
        ),
        overlayColor: WidgetStatePropertyAll(palette.menuPress),
        padding: WidgetStatePropertyAll(
          EdgeInsetsDirectional.only(
            start: iconOf == null
                ? _leadingWidth
                : _iconPadding.start - _materialMenuLabelGap,
            end: AppLayout.settingsTilePadH.w,
            top: AppLayout.settingsTilePadV.h,
            bottom: AppLayout.settingsTilePadV.h,
          ),
        ),
      ),
      labelWidget: _entryLabel(palette, choice, chosen),
      trailingIcon: chosen
          ? Icon(
              Iconsax.tick_circle_copy,
              color: palette.accent,
              size: AppLayout.settingsLanguageTick.sp,
            )
          : null,
    );
  }

  Icon _chevron(SettingsPalette palette, IconData icon) => Icon(
    icon,
    color: palette.chevron,
    size: AppLayout.settingsChevronSize.sp,
  );

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final selected = this.selected;
    final labelStyle = TextStyle(
      color: palette.textTertiary,
      fontSize: AppLayout.textMd.sp,
    );

    return DropdownMenu<T>(
      // Material writes the field's text only when the selection changes, so
      // a choice renamed under it — a translated label after a language
      // change — would keep its old name. A new name is a new field.
      key: ValueKey(selected == null ? null : labelOf(selected)),
      initialSelection: selected,
      onSelected: (picked) {
        if (picked != null) onSelected(picked);
      },
      // A short list has nothing to search, so the field only opens the
      // menu — on a desktop too, where Material would let it be typed into.
      selectOnly: true,
      expandedInsets: EdgeInsets.zero,
      label: Text(label),
      // Inset as a settings row insets its tile, and as far from the text.
      leadingIcon: Padding(
        padding: _iconPadding,
        child: SettingsTileIcon(icon: icon),
      ),
      trailingIcon: _chevron(palette, Iconsax.arrow_down_1_copy),
      selectedTrailingIcon: _chevron(palette, Iconsax.arrow_up_2_copy),
      textStyle: TextStyle(
        color: palette.textPrimary,
        fontFamily: _fontFamilyOf(selected),
        fontSize: AppLayout.textXl.sp,
        fontWeight: FontWeight.w500,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: InputBorder.none,
        // Material holds a leading icon to a 48-point square, which would
        // stretch the 32-point tile to fill it.
        prefixIconConstraints: const BoxConstraints(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppLayout.settingsTilePadH.w,
          vertical: AppLayout.settingsTilePadV.h,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: labelStyle,
        floatingLabelStyle: labelStyle,
      ),
      // Clear of the row, so the menu reads as raised over the card.
      alignmentOffset: Offset(0, AppLayout.settingsMenuGap.h),
      // A settings card: the card's corners and hairline rim, on the dialog's
      // surface, with no Material tint washing it towards the theme's seed.
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.menuSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(palette.menuShadow),
        elevation: const WidgetStatePropertyAll(
          AppLayout.settingsMenuElevation,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: AppLayout.settingsMenuPadV.h),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppLayout.settingsLanguageMenuRadius.r,
            ),
          ),
        ),
      ),
      dropdownMenuEntries: [
        for (final choice in choices) _entry(palette, choice),
      ],
    );
  }
}
