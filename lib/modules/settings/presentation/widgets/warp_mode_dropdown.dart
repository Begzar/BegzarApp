import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Picks the shape the WARP engine runs in while Experimental settings are on.
class WarpModeDropdown extends StatelessWidget {
  const WarpModeDropdown({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final WarpMode selected;
  final ValueChanged<WarpMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsDropdown<WarpMode>(
      icon: Iconsax.cloud_connection_copy,
      label: l10n.warpModeTitle,
      selected: selected,
      choices: WarpMode.values,
      labelOf: (mode) => switch (mode) {
        WarpMode.masque => l10n.warpModeMasque,
        WarpMode.warp => l10n.warpModeWarp,
        WarpMode.gool => l10n.warpModeGool,
        WarpMode.masquePsiphon => l10n.warpModeMasquePsiphon,
        WarpMode.psiphon => l10n.warpModePsiphon,
      },
      onSelected: onSelected,
    );
  }
}
