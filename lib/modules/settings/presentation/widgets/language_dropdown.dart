import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Picks the app's language, in Settings and on a first launch alike.
///
/// Every language is named in itself and set in its own face rather than
/// translated into the current one — someone looking for a language they can
/// read will not find it under a name, or in letters, they cannot.
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// Null leaves the field empty, for a locale the app has no language for.
  final AppLanguage? selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsDropdown<AppLanguage>(
      icon: Iconsax.global_copy,
      label: context.l10n.languageTitle,
      selected: selected,
      choices: AppLanguage.values,
      labelOf: (language) => language.nativeLabel,
      localeOf: (language) => language.locale,
      onSelected: onSelected,
    );
  }
}
