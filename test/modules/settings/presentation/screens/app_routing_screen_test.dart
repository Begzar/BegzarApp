import 'dart:convert';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/settings/data/datasources/installed_apps_data_source.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/screens/app_routing_screen.dart';
import 'package:begzar/modules/settings/presentation/widgets/app_routing_tile.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';
import '../../../../support/recording_analytics.dart';
import '../../settings_test_doubles.dart';

const _designSize = Size(393, 852);

/// The smallest phone the picker has to work on.
const _smallPhone = Size(360, 640);

/// A soft keyboard on that phone, and the status bar above the app.
const _keyboardHeight = 280.0;
const _statusBarHeight = 24.0;

/// Reports a fixed status without watching the service graph.
class _FixedConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.ready);
}

Finder _modeOption(AppRoutingMode mode) => find.byWidgetPredicate(
  (widget) => widget is RadioListTile<AppRoutingMode> && widget.value == mode,
);

Finder _tileOf(String packageName) => find.byWidgetPredicate(
  (widget) => widget is AppRoutingTile && widget.app.packageName == packageName,
);

Finder _switchOf(String packageName) =>
    find.descendant(of: _tileOf(packageName), matching: find.byType(Switch));

/// The summary bar's segments: the only flexed children on the screen that
/// are a bare block of colour.
Finder _summarySegments() => find.byWidgetPredicate(
  (widget) => widget is Expanded && widget.child is ColoredBox,
);

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppRoutingScreen)));

AppLocalizations _l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AppRoutingScreen)));

void main() {
  /// Mounts the picker on a [surface] over [launcher] and a store holding
  /// [stored]. A launcher that never answers leaves a spinner running, so
  /// [settle] is turned off for it.
  Future<void> pumpPicker(
    WidgetTester tester, {
    InstalledAppsDataSource launcher = const FakeInstalledApps([
      'com.a',
      'com.b',
    ]),
    Map<String, String> stored = const {},
    Size surface = _designSize,
    bool settle = true,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(_FixedConnection.new),
          analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(
              storage: SettingsStorage(storage: MemoryKeyedStorage(stored)),
              systemProxySupported: false,
              installedApps: launcher,
              ownPackage: () async => 'cloud.begzar.begzar',
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: _designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en')],
            home: AppRoutingScreen(),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('AppRoutingScreen', () {
    // A pick whose app has gone would otherwise vanish from the only place
    // it can be undone.
    testWidgets('should list a picked app that is no longer installed', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        stored: {
          'settings_app_routing_only_selected': jsonEncode(['com.gone']),
        },
      );

      expect(find.byType(AppRoutingTile), findsNWidgets(3));
      expect(_tileOf('com.gone'), findsOneWidget);
    });

    testWidgets('should switch the mode when the other choice is tapped', (
      tester,
    ) async {
      await pumpPicker(tester);

      await tester.tap(_modeOption(AppRoutingMode.onlySelected));
      await tester.pumpAndSettle();

      expect(
        _containerOf(tester).read(appRoutingProvider).mode,
        AppRoutingMode.onlySelected,
      );
    });

    // The Windows connection modes share this choice's rows and carry a chip
    // each; these two are a choice inside one setting and carry none.
    testWidgets('should draw the mode rows without an icon', (tester) async {
      await pumpPicker(tester);

      for (final mode in AppRoutingMode.values) {
        expect(_modeOption(mode), findsOneWidget, reason: '$mode');
        expect(
          find.descendant(
            of: _modeOption(mode),
            matching: find.byType(SettingsTileIcon),
          ),
          findsNothing,
          reason: '$mode',
        );
      }
    });

    testWidgets('should pick an app into the list in force', (tester) async {
      await pumpPicker(tester);

      await tester.tap(_switchOf('com.a'));
      await tester.pumpAndSettle();

      final selection = _containerOf(tester).read(appRoutingProvider);
      expect(selection.inForce, {'com.a'});
      expect(selection.onlySelected, isEmpty);
    });

    // Everything above the list used to stay put, so on a small phone the
    // keyboard took the whole of what the list had left.
    testWidgets(
      'should keep an app row in view while the keyboard is up on a small '
      'phone',
      (tester) async {
        tester.view.padding = const FakeViewPadding(top: _statusBarHeight);
        await pumpPicker(tester, surface: _smallPhone);

        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
        await tester.pumpAndSettle();

        final keyboardTop = _smallPhone.height - _keyboardHeight;
        final rows = find.byType(AppRoutingTile);
        expect(rows, findsWidgets);
        expect(tester.getRect(rows.first).top, lessThan(keyboardTop));
      },
    );

    // The tabs' nav bar floats over every screen pushed inside a tab, so a
    // list that ends at the screen's edge leaves its last app under the bar.
    testWidgets('should end the list above the floating nav bar', (
      tester,
    ) async {
      final packages = [
        for (var index = 0; index < 30; index++)
          'com.app${index.toString().padLeft(2, '0')}',
      ];
      await pumpPicker(tester, launcher: FakeInstalledApps(packages));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final navBarTop = _designSize.height - NavBar.footprint;
      expect(
        tester.getRect(_tileOf(packages.last)).bottom,
        lessThan(navBarTop),
      );
    });

    // Zero through the VPN and zero direct is not what a list that has not
    // arrived yet holds. The bar keeps its space while it loads, so it is
    // laid out but neither painted, reachable, nor announced.
    testWidgets('should not show the counts while the list is loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester, launcher: PendingInstalledApps(), settle: false);

      final l10n = _l10nOf(tester);
      for (final label in [
        l10n.appRoutingThroughVpn(0),
        l10n.appRoutingDirect(0),
      ]) {
        expect(find.text(label).hitTestable(), findsNothing, reason: label);
        expect(find.bySemanticsLabel(label), findsNothing, reason: label);
      }
      expect(
        tester
            .widget<Visibility>(
              find.ancestor(
                of: find.text(l10n.appRoutingDirect(0)),
                matching: find.byType(Visibility),
              ),
            )
            .visible,
        isFalse,
      );
      semantics.dispose();
    });

    // The summary bar arrives with the list, and a field that dropped by its
    // height could move out from under a finger about to tap it.
    testWidgets('should keep the search field in place when the list loads', (
      tester,
    ) async {
      final launcher = PendingInstalledApps();
      await pumpPicker(tester, launcher: launcher, settle: false);
      final whileLoading = tester.getRect(find.byType(TextField));

      launcher.answer(['com.a', 'com.b']);
      await tester.pumpAndSettle();

      expect(_summarySegments(), findsWidgets);
      expect(tester.getRect(find.byType(TextField)), whileLoading);
    });

    // A launcher that fails to answer comes back as an empty list, and
    // counting zero apps above "No apps found" says the same thing twice.
    testWidgets('should show the empty state and no counts for an empty list', (
      tester,
    ) async {
      await pumpPicker(tester, launcher: const FakeInstalledApps([]));

      final l10n = _l10nOf(tester);
      expect(find.text(l10n.noAppsFound), findsOneWidget);
      expect(find.text(l10n.appRoutingThroughVpn(0)), findsNothing);
      expect(find.text(l10n.appRoutingDirect(0)), findsNothing);
    });

    // A block of colour with no child of its own takes the least height it
    // is allowed, so a bar that only centred its segments drew an empty
    // track under counts that said otherwise.
    testWidgets('should draw each side of the summary bar at its full height', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        stored: {
          'settings_excluded_apps': jsonEncode(['com.b']),
        },
      );

      final segments = _summarySegments();
      expect(segments, findsNWidgets(2));
      final barHeight = tester
          .getSize(
            find.ancestor(of: segments.first, matching: find.byType(Row)),
          )
          .height;
      expect(barHeight, greaterThan(0));
      for (final segment in segments.evaluate()) {
        final size = segment.size!;
        expect(size.width, greaterThan(0));
        expect(size.height, barHeight);
      }
    });

    // The switch has no label of its own, and the letter standing in for a
    // missing icon is decoration: what a screen reader announces first on the
    // switch is the app's name.
    testWidgets('should announce the app by name on its switch', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester);

      final node = tester.getSemantics(_switchOf('com.a'));
      expect(node, isSemantics(hasToggledState: true));
      expect(node.getSemanticsData().label.split('\n').first, 'com.a');
      semantics.dispose();
    });
  }, skip: readsRunningPrograms ? desktopSkipReason : null);
}
