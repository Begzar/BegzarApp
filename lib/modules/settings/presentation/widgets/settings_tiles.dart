import 'package:begzar/core/widgets/directional_glyph.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A titled group of rows, drawn as one card.
///
/// The title is the only thing that separates one group from the next, so it
/// sits outside the card rather than as a first row inside it.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppLayout.settingsGroupLabelPadStart.w,
            bottom: AppLayout.settingsGroupLabelPadBottom.h,
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: AppLayout.textMd.sp,
              fontWeight: FontWeight.w600,
              color: palette.sectionLabel,
              letterSpacing: 0.6,
            ),
          ),
        ),
        SettingsGlassPanel(
          style: SettingsGlass.panel(
            palette,
            cornerRadius: AppLayout.settingsTabRadius.r,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ],
    );
  }
}

/// The hairline between two rows of a section.
///
/// Inset past the icon column, so the rule reads as separating rows rather
/// than cutting the card in half, and run out to the card's far edge. The
/// inset is at the start: on the left it put Persian's rule under the icons
/// and stopped it short of the end.
class SettingsSectionDivider extends StatelessWidget {
  const SettingsSectionDivider({super.key}) : _inset = true;

  /// A rule running the card's whole width, for either side of a block with
  /// no icon column — the LAN addresses under Bypass LAN. Inset, it stopped
  /// short over nothing, beside content that runs the full width.
  const SettingsSectionDivider.edgeToEdge({super.key}) : _inset = false;

  final bool _inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _inset ? AppLayout.settingsDividerInset.w : 0,
      ),
      child: Divider(
        height: 1,
        thickness: 1,
        color: SettingsPalette.of(context).divider,
      ),
    );
  }
}

/// A row that opens something else, and shows the current value under its
/// title so the screen answers without being tapped.
///
/// Without [onTap] it is a reading only: no chevron, and nothing to press.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconMark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Drawn on the icon's corner, for a row with news the user has not acted
  /// on.
  final Widget? iconMark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.settingsTilePadH.w,
            vertical: AppLayout.settingsTilePadV.h,
          ),
          child: Row(
            children: [
              SettingsTileIcon(icon: icon, mark: iconMark),
              SizedBox(width: AppLayout.settingsTileIconGap.w),
              Expanded(
                child: _TileText(title: title, subtitle: subtitle),
              ),
              if (onTap != null)
                Icon(
                  DirectionalGlyph.chevron(context),
                  color: SettingsPalette.of(context).chevron,
                  size: AppLayout.settingsChevronSize.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row carrying a switch, and optionally a chevron for the screen that
/// switch unlocks.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
    this.showChevron = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Where the chevron leads. Only reachable while the switch is on, since
  /// there is nothing to configure for a feature that is off.
  final VoidCallback? onTap;
  final bool showChevron;

  /// A row whose setting depends on another one that is off. Shown dimmed
  /// rather than hidden, so the dependency is visible.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : SettingsPalette.disabledOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && value ? onTap : null,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppLayout.settingsSwitchPadStart.w,
              AppLayout.settingsSwitchPadV.h,
              AppLayout.settingsSwitchPadEnd.w,
              AppLayout.settingsSwitchPadV.h,
            ),
            child: Row(
              children: [
                SettingsTileIcon(icon: icon),
                SizedBox(width: AppLayout.settingsTileIconGap.w),
                Expanded(
                  child: _TileText(
                    title: title,
                    subtitle: subtitle,
                    subtitleLines: 2,
                  ),
                ),
                if (showChevron)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: AppLayout.settingsSwitchChevronInset.w,
                    ),
                    child: Icon(
                      DirectionalGlyph.chevron(context),
                      color: SettingsPalette.of(context).chevron,
                      size: AppLayout.settingsChevronSize.sp,
                    ),
                  ),
                SettingsSwitch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The module's switch, sized down to sit inside a dense row.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 0.78,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  /// The width a switch takes at a row's end, centred in it: the box Flutter
  /// lays a shrink-wrapped switch out in, held here so the switch's centre
  /// line is a number of the module's rather than of the framework's. A
  /// radio row centres its radio on the same line.
  static const slotWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return SizedBox(
      width: slotWidth,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: palette.accent,
            activeTrackColor: palette.switchTrackOn,
            inactiveThumbColor: palette.switchThumbOff,
            inactiveTrackColor: palette.switchTrackOff,
          ),
        ),
      ),
    );
  }
}

/// The rounded tile a row's glyph sits in.
class SettingsTileIcon extends StatelessWidget {
  const SettingsTileIcon({
    super.key,
    required this.icon,
    this.mark,
    this.color,
  });

  final IconData icon;

  /// The glyph's colour, for a tile marking the chosen thing; the row's
  /// icon colour otherwise.
  final Color? color;

  /// Drawn over the tile's top corner at the end the row reads towards, so it
  /// follows the text into Persian.
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final tile = SettingsGlassPanel(
      style: SettingsGlass.chip(
        palette,
        cornerRadius: AppLayout.settingsChipRadius.r,
      ),
      child: SizedBox(
        width: AppLayout.settingsTileIconSize.w,
        height: AppLayout.settingsTileIconSize.w,
        child: Icon(
          icon,
          color: color ?? palette.icon,
          size: AppLayout.settingsTileGlyph.sp,
        ),
      ),
    );

    final mark = this.mark;
    if (mark == null) return tile;

    final overhang = -AppLayout.settingsTileIconMarkOverhang.w;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        PositionedDirectional(top: overhang, end: overhang, child: mark),
      ],
    );
  }
}

class _TileText extends StatelessWidget {
  const _TileText({
    required this.title,
    required this.subtitle,
    this.subtitleLines = 1,
  });

  final String title;
  final String subtitle;
  final int subtitleLines;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppLayout.textXl.sp,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary,
          ),
        ),
        SizedBox(height: AppLayout.settingsTileLabelGap.h),
        Text(
          subtitle,
          maxLines: subtitleLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppLayout.textMd.sp,
            color: palette.textTertiary,
            height: subtitleLines > 1 ? 1.3 : null,
          ),
        ),
      ],
    );
  }
}
