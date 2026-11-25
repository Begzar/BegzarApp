import 'dart:math' as math;

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/home_settings_line.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_analytics.dart';

/// Wider than a phone and laid out as its own design size, so at a scale of
/// one: the font the test binding substitutes draws every glyph as a
/// fixed-width box, and the line would otherwise run out of room and cut the
/// apps off. A wider surface against the phone's design would not help, since
/// the text scales up with the width.
const _surface = Size(640, 200);

/// The preferences a fresh install starts with, without storage behind them.
class _FixedSettings extends SettingsNotifier {
  _FixedSettings({required this.systemProxySupported});

  /// Whether this stands in for Windows, the one platform with three modes.
  final bool systemProxySupported;

  @override
  SettingsPreferences build() =>
      SettingsPreferences.initial(systemProxySupported: systemProxySupported);

  /// Switches the mode the way the settings screen would, minus the disk.
  void pick(ExposureMode mode) =>
      state = state.copyWith(exposure: state.exposure.withMode(mode));
}

/// Every app carried, without storage behind it.
class _FixedRouting extends AppRoutingNotifier {
  @override
  AppRoutingSelection build() => AppRoutingSelection.initial;
}

/// Mounts the line in [locale] and hands back the container it reads from.
Future<ProviderContainer> _pumpLine(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool systemProxySupported = false,
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _FixedSettings(systemProxySupported: systemProxySupported),
      ),
      appRoutingProvider.overrideWith(_FixedRouting.new),
      analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: _surface,
        builder: (context, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fa')],
          home: const Scaffold(body: HomeSettingsLine()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(HomeSettingsLine)));

/// The line's text, not the glyphs either side of it, which are text too.
Finder _line() => find.descendant(
  of: find.byType(HomeSettingsLine),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is RichText &&
        widget.text.toPlainText().contains(DnsServer.fallback.address),
  ),
);

/// The line's words, as one string.
String _lineText(WidgetTester tester) =>
    tester.widget<RichText>(_line()).text.toPlainText();

/// How far from the line's left edge [piece] is drawn.
double _leftOf(WidgetTester tester, String piece) {
  final paragraph = tester.renderObject<RenderParagraph>(_line());
  final start = paragraph.text.toPlainText().indexOf(piece);
  expect(start, isNonNegative, reason: '"$piece" is not on the line');
  return paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + piece.length),
      )
      .map((box) => box.left)
      .reduce(math.min);
}

void main() {
  group('HomeSettingsLine', () {
    testWidgets('should name the mode, the resolver and the apps a connect '
        'will use', (tester) async {
      await _pumpLine(tester);
      final l10n = _l10n(tester);

      final line = _lineText(tester);

      expect(line, contains(l10n.homeModeVpn));
      expect(line, contains(DnsServer.fallback.address));
      expect(line, contains(l10n.homeAppsAll));
    });

    testWidgets('should call each Windows mode what the settings screen '
        'calls it', (tester) async {
      final container = await _pumpLine(tester, systemProxySupported: true);
      final l10n = _l10n(tester);

      final expected = {
        ExposureMode.tunnel: l10n.connectionModeTunnel,
        ExposureMode.systemProxy: l10n.connectionModeSystemProxy,
        ExposureMode.proxyOnly: l10n.connectionModeProxyOnly,
      };
      for (final MapEntry(key: mode, value: name) in expected.entries) {
        (container.read(settingsProvider.notifier) as _FixedSettings).pick(
          mode,
        );
        await tester.pumpAndSettle();

        expect(_lineText(tester), contains(name), reason: mode.name);
      }
      expect(_lineText(tester), isNot(contains(l10n.homeModeVpn)));
    });

    // In Persian the tunnel is VPN, Latin like the resolver beside it, and
    // two Latin pieces in a right-to-left line once ran together and swapped
    // places: the line read resolver, mode, apps.
    testWidgets('should keep the mode first and the apps last in Persian, '
        'with a Latin mode name', (tester) async {
      await _pumpLine(tester, locale: const Locale('fa'));
      final l10n = _l10n(tester);

      final mode = _leftOf(tester, l10n.homeModeVpn);
      final dns = _leftOf(tester, l10n.homeFactDns);
      final apps = _leftOf(tester, l10n.homeAppsAll);

      expect(mode, greaterThan(dns));
      expect(dns, greaterThan(apps));
    });

    testWidgets('should keep the mode first and the apps last in English', (
      tester,
    ) async {
      await _pumpLine(tester);
      final l10n = _l10n(tester);

      final mode = _leftOf(tester, l10n.homeModeVpn);
      final dns = _leftOf(tester, l10n.homeFactDns);
      final apps = _leftOf(tester, l10n.homeAppsAll);

      expect(mode, lessThan(dns));
      expect(dns, lessThan(apps));
    });

    testWidgets('should open the settings tab when tapped', (tester) async {
      final container = await _pumpLine(tester);

      await tester.tap(find.byType(HomeSettingsLine));
      await tester.pumpAndSettle();

      expect(container.read(selectedTabProvider), settingIndex);
    });
  });
}
