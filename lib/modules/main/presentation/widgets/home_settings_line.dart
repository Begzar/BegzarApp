import 'dart:io' show Platform;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' show BidiFormatter;

/// How the next connect will be made — the mode, the resolver and which apps
/// it carries — in one line under the server it will use, a tap from the
/// settings that decide it.
///
/// It sat at the top of the screen once, in a card that also warned the
/// reader their address was in the open. These are not news: they are the
/// rest of the answer to what pressing the dial will do, so they read with
/// the server rather than above everything else.
class HomeSettingsLine extends ConsumerWidget {
  const HomeSettingsLine({super.key});

  /// Between two settings on the line. One space each side, so the apps
  /// still fit beside System proxy, the longest mode name on Windows.
  static const _separator = ' · ';

  /// Opens a piece of the line set in the direction of its first letter.
  static const _firstStrongIsolate = '\u2068';

  /// Closes the piece [_firstStrongIsolate] opened.
  static const _popDirectionalIsolate = '\u2069';

  /// Holds [spans] together as one piece of the line.
  ///
  /// The pieces mix scripts. In Persian the mode can be VPN and the resolver
  /// is always Latin, and two Latin pieces side by side in a right-to-left
  /// line join into one left-to-right run: the mode landed beyond the
  /// resolver whenever its name was Latin, and before it when it was
  /// Persian. Isolated, each piece keeps its place whatever it holds.
  static TextSpan _piece(List<InlineSpan> spans) => TextSpan(
    children: [
      const TextSpan(text: _firstStrongIsolate),
      ...spans,
      const TextSpan(text: _popDirectionalIsolate),
    ],
  );

  /// The mode as the line says it. Windows has three and names them as its
  /// settings screen does; everywhere else the tunnel is the platform's VPN.
  String _mode(AppLocalizations l10n, ProxyExposure exposure) {
    return switch (exposure.mode) {
      ExposureMode.tunnel when exposure.systemProxySupported =>
        l10n.connectionModeTunnel,
      ExposureMode.tunnel => l10n.homeModeVpn,
      ExposureMode.systemProxy => l10n.connectionModeSystemProxy,
      ExposureMode.proxyOnly => l10n.connectionModeProxyOnly,
    };
  }

  /// The apps the tunnel carries, as the line says them.
  String _apps(AppLocalizations l10n, AppRouting routing) {
    if (routing.apps.isEmpty) return l10n.homeAppsAll;
    return switch (routing.mode) {
      AppRoutingMode.allExcept => l10n.homeAppsExcept(routing.apps.length),
      AppRoutingMode.onlySelected => l10n.homeAppsOnly(routing.apps.length),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = MainPalette.of(context);
    final preferences = ref.watch(settingsProvider);
    final selection = ref.watch(appRoutingProvider);
    final exposure = preferences.exposure;

    final mode = _mode(l10n, exposure);

    // Android picks apps inside the VPN service, which proxy-only mode never
    // starts, so the list routes nothing there — the settings row says the
    // same by dimming.
    final routesApps = !(Platform.isAndroid && exposure.proxyOnly);
    final apps = _apps(
      l10n,
      selection.routingWhen(enabled: routesApps && preferences.appExclude),
    );

    // An address reads left to right in every locale; isolated, a Persian
    // line cannot reorder its digits around the dots.
    final dns = BidiFormatter.LTR().wrapWithUnicode(preferences.dnsServer);
    final faint = TextStyle(color: palette.textFaint);

    return Semantics(
      button: true,
      label:
          '${l10n.homeFactMode} $mode, '
          '${l10n.homeFactDns} ${preferences.dnsServer}, '
          '${l10n.homeFactApps} $apps',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () =>
              ref.read(selectedTabProvider.notifier).select(settingIndex),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.mainPanelInnerPaddingH.w,
              vertical: AppLayout.homeSettingsLinePadV.h,
            ),
            child: Row(
              children: [
                // Centred under the server's icon in the row above.
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start:
                        (AppLayout.mainServerRowLeadingBox.w -
                            AppLayout.homeSettingsLineGlyph.sp) /
                        2,
                  ),
                  child: Icon(
                    Iconsax.setting_4,
                    size: AppLayout.homeSettingsLineGlyph.sp,
                    color: palette.settingsLineGlyph,
                  ),
                ),
                SizedBox(width: AppLayout.homeSettingsLineGap.w),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        _piece([TextSpan(text: mode)]),
                        TextSpan(text: _separator, style: faint),
                        _piece([
                          TextSpan(text: '${l10n.homeFactDns} '),
                          TextSpan(
                            text: dns,
                            style: TextStyle(
                              fontFamily: monoFamilyOf(context),
                              color: palette.textPrimary,
                            ),
                          ),
                        ]),
                        TextSpan(text: _separator, style: faint),
                        _piece([TextSpan(text: apps)]),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppLayout.homeSettingsLineText.sp,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
