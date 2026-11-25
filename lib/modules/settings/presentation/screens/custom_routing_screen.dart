import 'package:begzar/core/widgets/directional_glyph.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/add_routing_rule_sheet.dart';
import 'package:begzar/modules/settings/presentation/widgets/routing_rules_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The rules that override where individual domains and addresses go.
///
/// One tab per action, in the order they read as a decision: let it past,
/// stop it, send it through the tunnel.
class CustomRoutingScreen extends ConsumerStatefulWidget {
  const CustomRoutingScreen({super.key});

  @override
  ConsumerState<CustomRoutingScreen> createState() =>
      _CustomRoutingScreenState();
}

class _CustomRoutingScreenState extends ConsumerState<CustomRoutingScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    RoutingAction.direct,
    RoutingAction.block,
    RoutingAction.proxy,
  ];

  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Adds to whichever tab is showing, so the action never has to be picked
  /// twice.
  void _addRule() =>
      showAddRoutingRuleSheet(context, _tabs[_tabController.index]);

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final rules = ref.watch(customRoutingProvider);

    return Scaffold(
      backgroundColor: palette.pageInk,
      body: DecoratedBox(
        decoration: palette.pageGlow,
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(onAdd: _addRule),
              _TabBar(controller: _tabController),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.settingsScreenInsetH.w,
                  AppLayout.gap12.h,
                  AppLayout.settingsScreenInsetH.w,
                  0,
                ),
                child: const _InfoBanner(),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final action in _tabs)
                      RoutingRulesTab(action: action, rules: rules),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsRoutingBarPadH.w,
        AppLayout.settingsRoutingBarPadTop.h,
        AppLayout.settingsRoutingBarPadH.w,
        AppLayout.settingsRoutingBarPadBottom.h,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              DirectionalGlyph.back(context),
              color: palette.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              l10n.routingRulesScreenTitle,
              style: TextStyle(
                fontSize: AppLayout.text5xl.sp,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: Icon(Iconsax.add, color: palette.textPrimary),
            tooltip: l10n.routingAddRule,
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppLayout.settingsScreenInsetH.w,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppLayout.settingsTabRadius.r),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: palette.cardRaised,
          borderRadius: BorderRadius.circular(
            AppLayout.settingsTabIndicatorRadius.r,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: palette.textPrimary,
        unselectedLabelColor: palette.textTertiary,
        labelStyle: TextStyle(
          fontSize: AppLayout.textLg.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(text: l10n.routingTabDirect),
          Tab(text: l10n.routingTabBlock),
          Tab(text: l10n.routingTabProxy),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.gap14.w,
        vertical: AppLayout.gap10.h,
      ),
      decoration: BoxDecoration(
        color: palette.cardInset,
        borderRadius: BorderRadius.circular(AppLayout.settingsFieldRadius.r),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Text(
        context.l10n.routingRulesHint,
        style: TextStyle(
          fontSize: AppLayout.textBase.sp,
          color: palette.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}
