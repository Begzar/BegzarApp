import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// One action's rules — its domains, then its addresses.
class RoutingRulesTab extends ConsumerWidget {
  const RoutingRulesTab({super.key, required this.action, required this.rules});

  final RoutingAction action;
  final CustomRoutingRules rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Domains first, then addresses: the two are stored apart and a mixed
    // ordering would make the list look arbitrary.
    final entries = <(RoutingEntryType, String)>[
      for (final domain in rules.domainsFor(action))
        (RoutingEntryType.domain, domain),
      for (final ip in rules.ipsFor(action)) (RoutingEntryType.ip, ip),
    ];

    if (entries.isEmpty) return _EmptyTab(action: action);

    return ListView.separated(
      // The tabs' nav bar floats over this screen too, so the list ends above
      // it rather than at the screen's edge.
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsScreenInsetH.w,
        AppLayout.gap16.h,
        AppLayout.settingsScreenInsetH.w,
        NavBar.clearance.w,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) =>
          SizedBox(height: AppLayout.settingsRoutingRowGap.h),
      itemBuilder: (context, index) {
        final (type, value) = entries[index];

        return RoutingRuleTile(
          value: value,
          type: type,
          accent: action.colorIn(SettingsPalette.of(context)),
          onDelete: () => ref
              .read(customRoutingProvider.notifier)
              .removeRule(action: action, type: type, value: value),
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.action});

  final RoutingAction action;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;
    final message = switch (action) {
      RoutingAction.direct => l10n.routingEmptyDirect,
      RoutingAction.block => l10n.routingEmptyBlock,
      RoutingAction.proxy => l10n.routingEmptyProxy,
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.settingsRoutingEmptyPad.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textTertiary,
            fontSize: AppLayout.textXl.sp,
          ),
        ),
      ),
    );
  }
}

/// One rule, with the glyph saying whether it matches on a name or an
/// address and the accent saying which action it belongs to.
class RoutingRuleTile extends StatelessWidget {
  const RoutingRuleTile({
    super.key,
    required this.value,
    required this.type,
    required this.accent,
    required this.onDelete,
  });

  final String value;
  final RoutingEntryType type;
  final Color accent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsGlassPanel(
      style: SettingsGlass.panel(
        palette,
        cornerRadius: AppLayout.settingsTabRadius.r,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.gap14.w,
          vertical: AppLayout.gap12.h,
        ),
        child: Row(
          children: [
            Container(
              width: AppLayout.settingsRoutingGlyph.w,
              height: AppLayout.settingsRoutingGlyph.w,
              decoration: BoxDecoration(
                color: SettingsPalette.actionTint(accent),
                borderRadius: BorderRadius.circular(
                  AppLayout.settingsDialogFieldRadius.r,
                ),
              ),
              child: Icon(
                type == RoutingEntryType.domain ? Iconsax.global : Iconsax.code,
                color: accent,
                size: AppLayout.settingsRoutingActionGlyph.sp,
              ),
            ),
            SizedBox(width: AppLayout.settingsRoutingActionGap.w),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: AppLayout.textXl.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Iconsax.trash,
                color: palette.textTertiary,
                size: AppLayout.settingsRoutingActionGlyph.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
