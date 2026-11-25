import 'package:begzar/core/layout/app_layout.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dart:io';

import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/states/available_update_state.dart';
import 'package:begzar/modules/app_update/presentation/update_page_launcher.dart';
import 'package:begzar/modules/app_update/presentation/widgets/update_dot.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/main/presentation/widgets/home_app_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/theme_mode_notifier.dart';
import 'package:begzar/modules/settings/presentation/screens/app_routing_screen.dart';
import 'package:begzar/modules/settings/presentation/screens/custom_routing_screen.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/bypass_lan_addresses_tile.dart';
import 'package:begzar/modules/settings/presentation/widgets/dns_server_dialog.dart';
import 'package:begzar/modules/settings/presentation/widgets/language_dropdown.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_footer.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_radio_options.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:begzar/modules/settings/presentation/widgets/theme_mode_dropdown.dart';
import 'package:begzar/modules/settings/presentation/widgets/warp_mode_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(settingsProvider);
    final update = ref.watch(availableUpdateProvider);
    final installedVersion = ref.watch(installedVersionProvider).value;
    final palette = SettingsPalette.of(context);

    return Scaffold(
      backgroundColor: palette.pageInk,
      body: DecoratedBox(
        decoration: palette.pageGlow,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeAppBar(),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(overscroll: false),
                  child: ListView(
                    // The nav bar floats over the foot of the list, so the
                    // last row scrolls clear of it rather than ending under it.
                    padding: EdgeInsets.fromLTRB(
                      AppLayout.settingsScreenPadH.w,
                      AppLayout.settingsScreenPadTop.h,
                      AppLayout.settingsScreenPadH.w,
                      NavBar.clearance.w,
                    ),
                    children: [
                      const _GeneralSection(),
                      SizedBox(height: AppLayout.settingsSectionGap.h),
                      _ConnectionSection(preferences: preferences),
                      SizedBox(height: AppLayout.settingsSectionGap.h),
                      const _NetworkSection(),
                      if (ref.watch(experimentalSupportedProvider)) ...[
                        SizedBox(height: AppLayout.settingsSectionGap.h),
                        _ExperimentalSection(preferences: preferences),
                      ],
                      if (installedVersion != null) ...[
                        SizedBox(height: AppLayout.settingsSectionGap.h),
                        _AppSection(
                          installedVersion: installedVersion,
                          update: update,
                        ),
                      ],
                      SizedBox(height: AppLayout.settingsSectionGap.h),
                      const SettingsReconnectNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The installed build, which is what a support conversation asks for — and,
/// while a newer release is out, the way to it.
///
/// One row in one place either way: it closes the list so version news does
/// not push connection and network choices down, and the update row carries
/// the same dot as the settings tab so the mark is still visible once found.
class _AppSection extends StatelessWidget {
  const _AppSection({required this.installedVersion, required this.update});

  final String installedVersion;
  final AvailableUpdateState? update;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final update = this.update;

    return SettingsSection(
      title: l10n.settingsCategoryApp,
      children: [
        if (update == null)
          SettingsNavTile(
            icon: Iconsax.mobile_copy,
            title: l10n.currentVersion,
            subtitle: installedVersion,
          )
        else
          SettingsNavTile(
            icon: Iconsax.import_1_copy,
            title: l10n.updateAvailableTitle,
            iconMark: const UpdateDot(),
            subtitle: l10n.updateAvailableVersions(
              update.version,
              installedVersion,
            ),
            onTap: () => UpdatePageLauncher.open(context, update.url),
          ),
      ],
    );
  }
}

class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: context.l10n.settingsCategoryGeneral,
      children: [
        LanguageDropdown(
          selected: AppLanguage.fromCode(
            ref.watch(localeProvider).languageCode,
          ),
          onSelected: ref.read(localeProvider.notifier).setLanguage,
        ),
        const SettingsSectionDivider(),
        ThemeModeDropdown(
          selected: ref.watch(themeModeProvider),
          onSelected: ref.read(themeModeProvider.notifier).setThemeMode,
        ),
      ],
    );
  }
}

/// How the engine carries traffic, and what it leaves out.
class _ConnectionSection extends ConsumerWidget {
  const _ConnectionSection({required this.preferences});

  final SettingsPreferences preferences;

  /// Windows: the three ways to carry traffic, as one choice where exactly
  /// one is in force. The two proxy modes' hints name the port each leaves
  /// open, as the engine actually bound it.
  Widget _connectionModeChoice(
    BuildContext context,
    WidgetRef ref,
    ProxyExposure exposure,
  ) {
    final l10n = context.l10n;
    final connection = ref.watch(connectionRepositoryProvider);

    // The choice opens the section, and the section's glass does not clip,
    // so the top corners are rounded here to keep a chosen first row's tint
    // inside it.
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppLayout.settingsTabRadius.r),
      ),
      child: SettingsRadioOptions<ExposureMode>(
        groupValue: exposure.mode,
        onChanged: (mode) =>
            ref.read(settingsProvider.notifier).setConnectionMode(mode),
        options: [
          SettingsRadioOption(
            value: ExposureMode.tunnel,
            title: l10n.connectionModeTunnel,
            hint: l10n.connectionModeTunnelHint,
            icon: Iconsax.shield_tick_copy,
          ),
          // The two proxy modes keep the glyphs their switches carried
          // before the modes were one choice.
          SettingsRadioOption(
            value: ExposureMode.systemProxy,
            title: l10n.connectionModeSystemProxy,
            hint: l10n.connectionModeSystemProxyHint(
              connection.activeHttpProxyPort,
            ),
            icon: Iconsax.cloud_connection_copy,
          ),
          SettingsRadioOption(
            value: ExposureMode.proxyOnly,
            title: l10n.connectionModeProxyOnly,
            hint: l10n.connectionModeProxyOnlyHint(connection.activeSocksPort),
            icon: Iconsax.lock_copy,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final exposure = preferences.exposure;

    return SettingsSection(
      title: l10n.settingsCategoryConnection,
      children: [
        // Only Windows has a system proxy, and with it a third mode; every
        // other platform has its own tunnel and one way to turn it off.
        if (exposure.systemProxySupported)
          _connectionModeChoice(context, ref, exposure)
        else
          SettingsSwitchTile(
            icon: Iconsax.lock_copy,
            title: l10n.proxyOnlyTitle,
            subtitle: exposure.proxyOnly
                ? l10n.proxyOnlyEnabled(
                    ref.watch(connectionRepositoryProvider).activeSocksPort,
                  )
                : l10n.proxyOnlyDisabled,
            value: exposure.proxyOnly,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setProxyOnly(value),
          ),
        const SettingsSectionDivider(),
        _bypassLanTile(context, ref, exposure),
        // The addresses only exist while the port is actually shared, so the
        // tile follows the same condition the toggle reports.
        // The addresses have no icon column, so the rules either side of
        // them run edge to edge.
        if (exposure.sharesWithLan) ...[
          const SettingsSectionDivider.edgeToEdge(),
          const BypassLanAddressesTile(),
        ],
        if (ref.watch(appRoutingSupportedProvider)) ...[
          if (exposure.sharesWithLan)
            const SettingsSectionDivider.edgeToEdge()
          else
            const SettingsSectionDivider(),
          _appRoutingTile(context, ref, exposure),
        ],
      ],
    );
  }

  Widget _bypassLanTile(
    BuildContext context,
    WidgetRef ref,
    ProxyExposure exposure,
  ) {
    final l10n = context.l10n;
    // Windows has no Proxy Only switch to turn on, only a mode to choose.
    final requiresProxyOnly = exposure.systemProxySupported
        ? l10n.bypassLanRequiresProxyMode
        : l10n.bypassLanRequiresProxy;

    return SettingsSwitchTile(
      icon: Iconsax.wifi_square_copy,
      title: l10n.bypassLanTitle,
      subtitle: !exposure.proxyOnly
          ? requiresProxyOnly
          : exposure.bypassLan
          ? l10n.bypassLanEnabled
          : l10n.bypassLanDisabled,
      value: exposure.sharesWithLan,
      enabled: exposure.proxyOnly,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setBypassLan(value);
        // Re-read on the way in: the addresses are about to be shown, and
        // the device may have joined a different network since last time.
        if (value) ref.invalidate(deviceLanIpsProvider);
      },
    );
  }

  /// The mode in force and how many apps it names, read from what the engine
  /// would be told, so a switch that is off or a list left empty both say
  /// that nothing is routed yet.
  String _appRoutingSubtitle(
    AppLocalizations l10n,
    AppRoutingSelection selection,
  ) {
    final routing = selection.routingWhen(enabled: preferences.appExclude);
    final count = routing.apps.length;
    if (count == 0) return l10n.appRoutingSubtitleNone;

    return switch (routing.mode) {
      AppRoutingMode.allExcept => l10n.appRoutingSubtitleAllExcept(count),
      AppRoutingMode.onlySelected => l10n.appRoutingSubtitleOnly(count),
    };
  }

  void _openAppRouting(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AppRoutingScreen()));
  }

  Widget _appRoutingTile(
    BuildContext context,
    WidgetRef ref,
    ProxyExposure exposure,
  ) {
    final l10n = context.l10n;
    final selection = ref.watch(appRoutingProvider);
    // Android picks apps inside the VPN service, which proxy-only mode never
    // starts.
    final enabled = !(Platform.isAndroid && exposure.proxyOnly);
    // A dimmed row reads off, as Bypass LAN does: the stored choice is kept,
    // but nothing is routed by it while the row cannot apply.
    final isOn = enabled && preferences.appExclude;

    return SettingsSwitchTile(
      icon: Iconsax.element_3_copy,
      title: l10n.appRoutingTitle,
      subtitle: enabled
          ? _appRoutingSubtitle(l10n, selection)
          : l10n.appRoutingNeedsVpn,
      value: isOn,
      enabled: enabled,
      showChevron: isOn,
      onTap: isOn ? () => _openAppRouting(context) : null,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setAppExclude(value);
        // Turning it on with nothing picked routes nothing differently, so
        // the picker opens straight away rather than leaving a switch that
        // has no visible effect.
        if (value) _openAppRouting(context);
      },
    );
  }
}

/// What the engine resolves with, and what it routes where.
/// Experimental settings: a free connect runs the WARP engine, in the mode
/// picked here, instead of dialling Begzar's servers. Shown only where the
/// engine is built in.
class _ExperimentalSection extends ConsumerWidget {
  const _ExperimentalSection({required this.preferences});

  final SettingsPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.read(settingsProvider.notifier);

    return SettingsSection(
      title: l10n.settingsCategoryExperimental,
      children: [
        SettingsSwitchTile(
          icon: Iconsax.flash_1_copy,
          title: l10n.experimentalTitle,
          subtitle: preferences.experimental
              ? l10n.experimentalEnabled
              : l10n.experimentalDisabled,
          value: preferences.experimental,
          onChanged: settings.setExperimental,
        ),
        if (preferences.experimental) ...[
          const SettingsSectionDivider(),
          WarpModeDropdown(
            selected: preferences.warpMode,
            onSelected: settings.setWarpMode,
          ),
        ],
      ],
    );
  }
}

class _NetworkSection extends ConsumerWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dnsServer = ref.watch(
      settingsProvider.select((preferences) => preferences.dnsServer),
    );
    final rules = ref.watch(customRoutingProvider);

    return SettingsSection(
      title: l10n.settingsCategoryNetwork,
      children: [
        SettingsNavTile(
          icon: Iconsax.driver_2_copy,
          title: l10n.dnsServerTitle,
          subtitle: dnsServer,
          onTap: () => showDnsServerDialog(context, dnsServer),
        ),
        const SettingsSectionDivider(),
        SettingsNavTile(
          icon: Iconsax.routing_copy,
          title: l10n.routingRulesTitle,
          subtitle: _rulesSubtitle(l10n, rules),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomRoutingScreen()),
          ),
        ),
      ],
    );
  }

  String _rulesSubtitle(AppLocalizations l10n, CustomRoutingRules rules) {
    return rules.totalCount == 0
        ? l10n.routingRulesSubtitle
        : l10n.routingRulesCount(rules.totalCount);
  }
}
