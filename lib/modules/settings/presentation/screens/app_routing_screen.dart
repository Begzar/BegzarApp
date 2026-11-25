import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/directional_glyph.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/app_routing_tile.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_radio_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Picks which apps use the tunnel: a mode, and the apps that mode lists.
class AppRoutingScreen extends ConsumerStatefulWidget {
  const AppRoutingScreen({super.key});

  @override
  ConsumerState<AppRoutingScreen> createState() => _AppRoutingScreenState();
}

class _AppRoutingScreenState extends ConsumerState<AppRoutingScreen> {
  List<InstalledApp> _apps = const [];
  bool _isLoading = true;
  String _searchQuery = '';

  Future<void> _loadApps() async {
    // The stored picks have to land first: a pick whose app is not listed
    // right now is only shown because it is asked for here.
    await ref.read(appRoutingProvider.notifier).ensureLoaded();
    if (!mounted) return;

    // The list arrives sorted and free of unlaunchable and unnamed entries and
    // of Begzar itself, because the data layer is what talks to the platform,
    // and it fails to an empty list rather than throwing.
    final apps = await ref
        .read(settingsServiceProvider)
        .loadInstalledApps(picked: ref.read(appRoutingProvider).everPicked);
    if (!mounted) return;

    setState(() {
      _apps = apps;
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  /// The list, or what stands in for it: a spinner while it loads, and the
  /// empty state when there is nothing to show. A stand-in fills whatever
  /// height the blocks above it leave.
  Widget _listSliver(AppRoutingSelection selection) {
    if (_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            color: SettingsPalette.of(context).textPrimary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final filteredApps = _apps
        .where((app) => app.matches(_searchQuery))
        .toList();
    if (filteredApps.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(isSearching: _searchQuery.trim().isNotEmpty),
      );
    }

    return _AppsList(apps: filteredApps, selection: selection);
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final selection = ref.watch(appRoutingProvider);
    final notifier = ref.read(appRoutingProvider.notifier);
    final throughVpn = _apps
        .where((app) => selection.usesVpn(app.packageName))
        .length;

    return Scaffold(
      backgroundColor: palette.pageInk,
      body: DecoratedBox(
        decoration: palette.pageGlow,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AppBar(
                canClear: selection.inForce.isNotEmpty,
                onClearAll: notifier.clearPicked,
              ),
              // Everything under the app bar scrolls with the apps: held
              // still, these blocks left a small phone's list no room at all
              // once the keyboard came up for the search.
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ModeChoice(
                            mode: selection.mode,
                            onChanged: notifier.setMode,
                          ),
                          // A list that has not arrived, or arrived empty, has
                          // nothing to count: zero and zero would sit above
                          // the empty state. While it loads the bar still
                          // holds its space, so the search field under it
                          // does not drop when the list lands.
                          if (_isLoading || _apps.isNotEmpty)
                            Visibility(
                              visible: !_isLoading,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: _RoutingSummary(
                                throughVpn: throughVpn,
                                direct: _apps.length - throughVpn,
                              ),
                            ),
                          _PickLine(mode: selection.mode),
                          _SearchField(
                            onChanged: (query) =>
                                setState(() => _searchQuery = query),
                          ),
                        ],
                      ),
                    ),
                    _listSliver(selection),
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
  const _AppBar({required this.canClear, required this.onClearAll});

  /// Whether the list in force has anything in it to clear.
  final bool canClear;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppLayout.settingsAppRoutingBarPadStart.w,
        AppLayout.settingsAppRoutingBarPadTop.h,
        AppLayout.settingsAppRoutingBarPadEnd.w,
        AppLayout.settingsAppRoutingBarPadBottom.h,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              DirectionalGlyph.back(context),
              color: palette.textPrimary,
            ),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              l10n.appRoutingTitle,
              style: TextStyle(
                fontSize: AppLayout.text5xl.sp,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          if (canClear)
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.settingsAppRoutingTabPad.w,
                ),
              ),
              child: Text(
                l10n.clearAll,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: AppLayout.textBase.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two modes, as one choice on a card.
class _ModeChoice extends StatelessWidget {
  const _ModeChoice({required this.mode, required this.onChanged});

  final AppRoutingMode mode;
  final ValueChanged<AppRoutingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsAppRoutingSectionPadH.w,
        AppLayout.settingsAppRoutingModesPadTop.h,
        AppLayout.settingsAppRoutingSectionPadH.w,
        0,
      ),
      // Clips the rows to the card's corners, so the chosen row's tint stops
      // where the card does.
      child: Material(
        color: palette.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.settingsTabRadius.r),
          side: BorderSide(color: palette.border),
        ),
        child: SettingsRadioOptions<AppRoutingMode>(
          groupValue: mode,
          onChanged: onChanged,
          options: [
            SettingsRadioOption(
              value: AppRoutingMode.allExcept,
              title: l10n.appRoutingModeAllExcept,
              hint: l10n.appRoutingModeAllExceptHint,
            ),
            SettingsRadioOption(
              value: AppRoutingMode.onlySelected,
              title: l10n.appRoutingModeOnly,
              hint: l10n.appRoutingModeOnlyHint,
            ),
          ],
        ),
      ),
    );
  }
}

/// How the listed apps split between the tunnel and a direct connection, as
/// a bar and the two counts under it.
class _RoutingSummary extends StatelessWidget {
  const _RoutingSummary({required this.throughVpn, required this.direct});

  final int throughVpn;
  final int direct;

  /// One side of the bar. A side with no apps is left out, so the other one
  /// fills the bar.
  Widget _segment(int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Expanded(
      flex: count,
      child: ColoredBox(color: color),
    );
  }

  Widget _count(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: AppLayout.textMd.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;
    final vpnColor = RoutingAction.proxy.colorIn(palette);
    final directColor = RoutingAction.direct.colorIn(palette);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsAppRoutingSectionPadH.w,
        AppLayout.settingsAppRoutingSummaryPadTop.h,
        AppLayout.settingsAppRoutingSectionPadH.w,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              AppLayout.settingsAppRoutingSummaryRadius.r,
            ),
            child: Container(
              height: AppLayout.settingsAppRoutingSummaryHeight.h,
              color: palette.divider,
              // Stretches the segments, because each one is a bare block of
              // colour that would otherwise take no height at all.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _segment(throughVpn, vpnColor),
                  _segment(direct, directColor),
                ],
              ),
            ),
          ),
          SizedBox(height: AppLayout.settingsAppRoutingSummaryGap.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _count(l10n.appRoutingThroughVpn(throughVpn), vpnColor),
              _count(l10n.appRoutingDirect(direct), directColor),
            ],
          ),
        ],
      ),
    );
  }
}

/// What turning an app's switch on does in this mode.
class _PickLine extends StatelessWidget {
  const _PickLine({required this.mode});

  final AppRoutingMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsAppRoutingSectionPadH.w,
        AppLayout.settingsAppRoutingPickPadTop.h,
        AppLayout.settingsAppRoutingSectionPadH.w,
        0,
      ),
      child: Text(
        switch (mode) {
          AppRoutingMode.allExcept => l10n.appRoutingPickAllExcept,
          AppRoutingMode.onlySelected => l10n.appRoutingPickOnly,
        },
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: AppLayout.textBase.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsAppRoutingSearchPadH.w,
        AppLayout.settingsAppRoutingSearchPadTop.h,
        AppLayout.settingsAppRoutingSearchPadH.w,
        AppLayout.settingsAppRoutingSearchPadBottom.h,
      ),
      child: Container(
        height: AppLayout.settingsAppRoutingSearchHeight.h,
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.settingsAppRoutingSearchInset.w,
        ),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(
            AppLayout.settingsDialogFieldRadius.r,
          ),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(
              Iconsax.search_normal_copy,
              color: palette.textMuted,
              size: AppLayout.settingsAppRoutingSearchGlyph.sp,
            ),
            SizedBox(width: AppLayout.settingsAppRoutingSearchGap.w),
            Expanded(
              child: TextField(
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: AppLayout.textLg.sp,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.searchAppsHint,
                  hintStyle: TextStyle(
                    color: palette.textMuted,
                    fontSize: AppLayout.textLg.sp,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsList extends ConsumerWidget {
  const _AppsList({required this.apps, required this.selection});

  final List<InstalledApp> apps;
  final AppRoutingSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = SettingsPalette.of(context);
    return SliverPadding(
      // The tabs' nav bar floats over this screen too, so the list ends above
      // it rather than at the screen's edge.
      padding: EdgeInsets.fromLTRB(
        AppLayout.settingsAppRoutingListPadH.w,
        0,
        AppLayout.settingsAppRoutingListPadH.w,
        NavBar.clearance.w,
      ),
      // The rows sit inset from the card's edges by more than its corners
      // curve in, so the card needs no clip to keep a picked row's tint
      // inside it.
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppLayout.settingsTabRadius.r),
          border: Border.all(color: palette.border),
        ),
        sliver: SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.settingsAppRoutingGroupPadH.w,
            vertical: AppLayout.settingsAppRoutingGroupPadV.h,
          ),
          sliver: SliverList.separated(
            itemCount: apps.length,
            separatorBuilder: (_, _) => Padding(
              padding: EdgeInsetsDirectional.only(
                start: AppLayout.settingsAppRoutingDividerInset.w,
              ),
              child: Divider(height: 1, thickness: 1, color: palette.divider),
            ),
            itemBuilder: (context, index) {
              final app = apps[index];

              return AppRoutingTile(
                app: app,
                picked: selection.inForce.contains(app.packageName),
                usesVpn: selection.usesVpn(app.packageName),
                onChanged: (picked) => ref
                    .read(appRoutingProvider.notifier)
                    .setPicked(app.packageName, picked: picked),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching});

  /// Distinguishes "this device has no apps to list" from "your search
  /// matched none of them", which need different next steps.
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.settingsAppRoutingEmptyPad.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.search_zoom_out_copy,
              size: AppLayout.settingsAppRoutingEmptyGlyph.sp,
              color: palette.textMuted,
            ),
            SizedBox(height: AppLayout.settingsAppRoutingEmptyGap.h),
            Text(
              isSearching ? l10n.noSearchResults : l10n.noAppsFound,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textTertiary,
                fontSize: AppLayout.textLg.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
