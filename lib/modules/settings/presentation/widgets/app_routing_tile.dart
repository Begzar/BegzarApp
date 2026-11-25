import 'dart:typed_data';

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One app in the app-routing list.
///
/// The id is shown under the label, not as decoration: two apps can carry the
/// same label, and the id is what the routing actually matches.
class AppRoutingTile extends StatelessWidget {
  const AppRoutingTile({
    super.key,
    required this.app,
    required this.picked,
    required this.usesVpn,
    required this.onChanged,
  });

  final InstalledApp app;

  /// Whether the app is in the list the current mode reads.
  final bool picked;

  /// Where the app's traffic ends up under that list.
  final bool usesVpn;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return Material(
      // Tints the row, so the picked apps can be found while scrolling rather
      // than only by reading each switch.
      color: picked ? palette.selectedRow : Colors.transparent,
      // Merges the row into one node, so the switch is announced with the app
      // it belongs to rather than as a bare switch.
      child: MergeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.settingsAppRoutingPadH.w,
            vertical: AppLayout.settingsAppRoutingPadV.h,
          ),
          child: Row(
            children: [
              _AppIcon(app: app),
              SizedBox(width: AppLayout.settingsAppRoutingGap.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: AppLayout.textLg.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppLayout.settingsAppRoutingLabelGap.h),
                    Text(
                      app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontSize: AppLayout.textSm.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppLayout.settingsAppRoutingBadgeGap.w),
              _RouteTag(usesVpn: usesVpn),
              SizedBox(width: AppLayout.settingsAppRoutingBadgeGap.w),
              SettingsSwitch(value: picked, onChanged: onChanged, scale: 0.75),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the app ends up, in the colours custom routing uses for Proxy and
/// Direct, so the two screens mean the same thing by the same colour.
class _RouteTag extends StatelessWidget {
  const _RouteTag({required this.usesVpn});

  final bool usesVpn;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;
    final color = usesVpn
        ? RoutingAction.proxy.colorIn(palette)
        : RoutingAction.direct.colorIn(palette);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.settingsAppRoutingTagPadH.w,
        vertical: AppLayout.settingsAppRoutingTagPadV.h,
      ),
      decoration: BoxDecoration(
        color: SettingsPalette.actionTint(color),
        borderRadius: BorderRadius.circular(
          AppLayout.settingsAppRoutingTagRadius.r,
        ),
      ),
      child: Text(
        usesVpn ? l10n.appRoutingTagVpn : l10n.appRoutingTagDirect,
        style: TextStyle(
          color: color,
          fontSize: AppLayout.textSm.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The launcher icon, or the label's first letter when there is none: a
/// desktop program, a pick that is no longer installed, or bytes that will
/// not decode.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  final InstalledApp app;

  // Keeps the tile out of the semantics tree, because the label beside it
  // already says the name the letter is taken from.
  Widget _letterTile(SettingsPalette palette) {
    return ExcludeSemantics(
      child: SettingsGlassPanel(
        style: SettingsGlass.chip(
          palette,
          cornerRadius: AppLayout.settingsChipRadius.r,
        ),
        child: SizedBox(
          width: AppLayout.settingsAppRoutingIcon.w,
          height: AppLayout.settingsAppRoutingIcon.w,
          child: Center(
            child: Text(
              app.name.characters.firstOrNull?.toUpperCase() ?? '',
              style: TextStyle(
                color: palette.icon,
                fontSize: AppLayout.textXl.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final bytes = app.icon;
    if (bytes == null || bytes.isEmpty) return _letterTile(palette);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppLayout.settingsChipRadius.r),
      child: Image.memory(
        Uint8List.fromList(bytes),
        width: AppLayout.settingsAppRoutingIcon.w,
        height: AppLayout.settingsAppRoutingIcon.w,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _letterTile(palette),
      ),
    );
  }
}
