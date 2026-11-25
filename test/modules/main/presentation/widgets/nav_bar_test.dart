import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/states/available_update_state.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../support/recording_analytics.dart';

const _designSize = Size(393, 852);

/// What a screen reader hears on the settings tab while an update waits,
/// spelled out rather than read back from the localizations under test.
const _updateLabel = 'Update available';

/// What a screen reader hears on each tab, spelled out the same way.
const _settingsLabel = 'Settings';
const _homeLabel = 'Home';
const _premiumLabel = 'Premium';

/// Reports a fixed status without watching the service graph.
class _FixedConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.ready);
}

/// Holds a fixed optional update without a version check behind it.
class _FixedUpdate extends AvailableUpdateNotifier {
  _FixedUpdate(this.update);

  final AvailableUpdateState? update;

  @override
  AvailableUpdateState? build() => update;
}

const _update = AvailableUpdateState(
  version: '7.0.0',
  url: 'https://example.test/update',
);

/// The seat the settings tab is selected with.
Finder _settingsSeat() => find.ancestor(
  of: find.byIcon(Iconsax.setting_2_copy),
  matching: find.byType(InkWell),
);

/// The bar alone, in English, with home selected.
Widget _app() => ScreenUtilInit(
  designSize: _designSize,
  builder: (context, _) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: NavBar(selected: homeIndex, onSelect: (_) {}),
  ),
);

Future<void> _pumpBar(WidgetTester tester, AvailableUpdateState? update) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionProvider.overrideWith(_FixedConnection.new),
        availableUpdateProvider.overrideWith(() => _FixedUpdate(update)),
      ],
      child: _app(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NavBar', () {
    testWidgets('should mark the settings tab while an update is out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, _update);

      expect(
        find.descendant(
          of: _settingsSeat(),
          matching: find.bySemanticsLabel(_updateLabel),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('should not mark the settings tab without an update', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, null);

      expect(find.bySemanticsLabel(_updateLabel), findsNothing);
      semantics.dispose();
    });

    // An icon alone tells a screen reader, or anything driving the app from
    // its accessibility tree, nothing about which tab it opens.
    testWidgets('should name each tab and say which one is selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBar(tester, null);

      expect(
        tester.getSemantics(find.bySemanticsLabel(_settingsLabel)),
        isSemantics(
          label: _settingsLabel,
          isButton: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(_homeLabel)),
        isSemantics(
          label: _homeLabel,
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel(_premiumLabel), findsOneWidget);
      semantics.dispose();
    });

    // A blur behind the bar re-ran on every frame anything moved under it,
    // which held the GPU busy enough to stutter the notification shade.
    testWidgets('should draw the bar without a blur', (tester) async {
      await _pumpBar(tester, null);

      expect(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    // A white pill was the brightest thing on the home screen and pulled the
    // eye from the dial. The selected tab takes the accent, which is what the
    // app calls "the selected thing", at a tint.
    testWidgets('should draw the selected tab in the accent', (tester) async {
      await _pumpBar(tester, null);

      expect(
        tester.widget<Icon>(find.byIcon(Iconsax.home_copy)).color,
        isSameColorAs(AppPalette.dark.accent),
      );
    });

    // The faint rung fell short of the 3:1 a glyph needs on the bar.
    testWidgets('should draw a resting tab in the muted ink', (tester) async {
      await _pumpBar(tester, null);

      expect(
        tester.widget<Icon>(find.byIcon(Iconsax.user_copy)).color,
        isSameColorAs(AppPalette.dark.muted),
      );
    });

    // The dot is there to wear the user down into updating, so having looked
    // at settings is not having dealt with it.
    testWidgets('should keep marking the settings tab after settings opens', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionProvider.overrideWith(_FixedConnection.new),
            analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
          ],
          child: _app(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavBar)),
      );

      container
          .read(availableUpdateProvider.notifier)
          .publish(version: '7.0.0', url: 'https://example.test/update');
      await tester.pumpAndSettle();
      container.read(selectedTabProvider.notifier).select(settingIndex);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _settingsSeat(),
          matching: find.bySemanticsLabel(_updateLabel),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
