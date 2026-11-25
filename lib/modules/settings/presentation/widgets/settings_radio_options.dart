import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One row of a [SettingsRadioOptions]: the value it stands for, its name,
/// a line saying what choosing it does, and optionally a glyph for its chip.
class SettingsRadioOption<T> {
  const SettingsRadioOption({
    required this.value,
    required this.title,
    required this.hint,
    this.icon,
  });

  final T value;
  final String title;
  final String hint;

  /// Drawn in a [SettingsTileIcon] at the row's start, with the radio moved
  /// to its end. A row without one leads with its radio.
  final IconData? icon;
}

/// A choice where exactly one of [options] is in force, drawn as rows with a
/// radio each and a hairline between them.
///
/// A row given an icon is laid out as a [SettingsSwitchTile] is, with its
/// insets and gaps, so a choice opening a section lines up with the switch
/// rows under it.
///
/// It brings a transparent [Material] of its own, so the chosen row's tint is
/// painted over the card or glass section holding it rather than on the page
/// underneath.
class SettingsRadioOptions<T> extends StatelessWidget {
  const SettingsRadioOptions({
    super.key,
    required this.groupValue,
    required this.options,
    required this.onChanged,
  });

  final T groupValue;
  final List<SettingsRadioOption<T>> options;
  final ValueChanged<T> onChanged;

  /// How far an iconed row is inset at its end, so its radio is centred on
  /// the line a switch row's switch is: half a [SettingsSwitch.slotWidth] in
  /// from the switch rows' own end inset.
  ///
  /// The radio is smaller than the switch's slot, and by how much depends on
  /// the density — a radio laid out shrink-wrapped is 40 across at standard
  /// density and 32 at a desktop's compact one — so the inset is worked out
  /// from the radio the theme will draw. Sharing the end inset alone left
  /// the radios 10 points nearer the edge than the switches on a phone and
  /// 14 on Windows.
  static double _iconedEndInset(BuildContext context) {
    final theme = Theme.of(context);
    final density = theme.radioTheme.visualDensity ?? theme.visualDensity;
    final radio = kMinInteractiveDimension - 8 + density.baseSizeAdjustment.dx;
    return AppLayout.settingsSwitchPadEnd.w +
        (SettingsSwitch.slotWidth - radio) / 2;
  }

  Widget _row(
    BuildContext context,
    SettingsPalette palette,
    SettingsRadioOption<T> option,
  ) {
    final icon = option.icon;
    final hint = Text(
      option.hint,
      style: TextStyle(
        fontSize: AppLayout.textMd.sp,
        color: palette.textTertiary,
      ),
    );

    // Every argument that depends on the icon is left at the tile's default
    // without one, so a row with no icon is drawn as it always was.
    return RadioListTile<T>(
      value: option.value,
      selected: option.value == groupValue,
      selectedTileColor: palette.selectedRow,
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.accent
            : palette.switchThumbOff,
      ),
      secondary: icon == null ? null : SettingsTileIcon(icon: icon),
      controlAffinity: icon == null ? null : ListTileControlAffinity.trailing,
      contentPadding: icon == null
          ? EdgeInsets.symmetric(horizontal: AppLayout.settingsTilePadH.w)
          : EdgeInsetsDirectional.only(
              start: AppLayout.settingsSwitchPadStart.w,
              end: _iconedEndInset(context),
            ),
      // The tile pads its text vertically by itself, so a switch row's
      // vertical inset goes here rather than into the content padding.
      minVerticalPadding: icon == null ? null : AppLayout.settingsSwitchPadV.h,
      // With no minimum height the tile always stacks the inset, the title,
      // the hint and the inset, as a switch row does. Its two-line minimum
      // would centre a one-line hint in a taller row instead, and swallow
      // the gap above the hint.
      minTileHeight: icon == null ? null : 0,
      // The chip's own width decides where the text starts, as in a switch
      // row, rather than the tile's minimum for a leading widget.
      minLeadingWidth: icon == null ? null : 0,
      horizontalTitleGap: icon == null ? null : AppLayout.settingsTileIconGap.w,
      // A desktop theme is compact, and the tile narrows its gaps for that.
      // SettingsSwitchTile is a hand-built Row that density does not reach,
      // so the tile is held at standard to stay in line with it. This
      // reaches the tile alone, not the radio.
      visualDensity: icon == null ? null : VisualDensity.standard,
      title: Text(
        option.title,
        style: TextStyle(
          fontSize: AppLayout.textXl.sp,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
      ),
      subtitle: icon == null
          ? hint
          : Padding(
              padding: EdgeInsetsDirectional.only(
                top: AppLayout.settingsTileLabelGap.h,
              ),
              child: hint,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: RadioGroup<T>(
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
        child: Column(
          children: [
            for (final (index, option) in options.indexed) ...[
              // Rows that open with a chip are divided as the switch rows
              // under them are, clear of the chips; plain rows edge to edge.
              if (index > 0)
                option.icon != null
                    ? const SettingsSectionDivider()
                    : Divider(height: 1, thickness: 1, color: palette.divider),
              _row(context, palette, option),
            ],
          ],
        ),
      ),
    );
  }
}
