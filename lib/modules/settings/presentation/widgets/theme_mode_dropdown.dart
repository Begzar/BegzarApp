import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Picks whether the app is drawn light, dark, or as the phone is set.
class ThemeModeDropdown extends StatelessWidget {
  const ThemeModeDropdown({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsDropdown<ThemeMode>(
      // Not the moon: that marks Dark in the menu, and the row is about the
      // choice as a whole.
      icon: Iconsax.colorfilter_copy,
      label: l10n.themeTitle,
      selected: selected,
      choices: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
      labelOf: (mode) => switch (mode) {
        ThemeMode.system => l10n.themeSystem,
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
      },
      iconOf: (mode) => switch (mode) {
        ThemeMode.system => Iconsax.mobile_copy,
        ThemeMode.light => Iconsax.sun_1_copy,
        ThemeMode.dark => Iconsax.moon_copy,
      },
      onSelected: onSelected,
    );
  }
}
