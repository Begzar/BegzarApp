import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/states/force_update_state.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/screens/main_screen.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_button.dart';
import 'package:begzar/modules/main/presentation/widgets/home_server_row.dart';
import 'package:begzar/modules/main/presentation/widgets/home_settings_line.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _designSize = Size(393, 852);

/// A gesture-navigation inset worth having.
///
/// The screen's own [SafeArea] and the bar both answer to it — the bar floats
/// at `MediaQuery.padding.bottom + its own margin` — and the reserve the
/// screen keeps has to survive that being true. At an inset of zero a reserve
/// that subtracted it and one that did not would measure the same, and the
/// screen would go on looking right until it reached a real phone.
const _bottomInset = 34.0;

class _FixedConnection extends ConnectionNotifier {
  _FixedConnection(this.status);

  final ConnectionStatus status;

  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: status);
}

class _FixedPremium extends PremiumNotifier {
  @override
  PremiumState build() => const PremiumSignedOut();
}

class _FixedServers extends PremiumServersNotifier {
  @override
  PremiumServersState build() => const PremiumServersState();
}

/// Nothing to update to, so the screen never raises the blocking dialog over
/// the layout under test.
class _NoForcedUpdate extends ForceUpdateNotifier {
  @override
  ForceUpdateState build() => const ForceUpdateState();
}

/// The home screen under the bar, arranged the way `RootScreen` arranges them:
/// the screen fills the stack and the bar floats over it. Measuring the two
/// apart would only ever confirm the screen agrees with itself.
Future<void> _pumpHomeUnderTheBar(
  WidgetTester tester, {
  required Size surface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionProvider.overrideWith(
          () => _FixedConnection(ConnectionStatus.ready),
        ),
        premiumProvider.overrideWith(_FixedPremium.new),
        premiumServersProvider.overrideWith(_FixedServers.new),
        forceUpdateProvider.overrideWith(_NoForcedUpdate.new),
        ipInfoProvider.overrideWith((ref) async => null),
      ],
      child: ScreenUtilInit(
        designSize: _designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fa')],
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: _bottomInset),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  const MainScreen(),
                  Positioned(
                    bottom: NavBar.bottomInset.w + _bottomInset,
                    left: 0,
                    right: 0,
                    child: NavBar(selected: homeIndex, onSelect: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Not pumpAndSettle: the dial breathes on a loop that never finishes. Two
  // frames are enough for the layout to settle, which is all this measures.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  /// The air above the server row and the air below it, on a screen of
  /// [surface].
  ///
  /// The bar's top edge is read off the bar as drawn rather than worked out
  /// from the constants, so a reserve that disagrees with where the bar
  /// actually sits fails here instead of looking right on paper.
  Future<(double above, double below)> gaps(
    WidgetTester tester, {
    required Size surface,
  }) async {
    await _pumpHomeUnderTheBar(tester, surface: surface);

    final dial = tester.getRect(find.byType(ConnectionButtonWidget));
    final row = tester.getRect(find.byType(HomeServerRow));
    final barTop = tester.getRect(find.byType(NavBar)).top;

    return (row.top - dial.bottom, barTop - row.bottom);
  }

  group('the server row sits centred between the dial and the nav bar', () {
    testWidgets('on a phone-sized screen', (tester) async {
      final (above, below) = await gaps(tester, surface: const Size(393, 852));

      expect(above, greaterThan(0));
      expect(above, moreOrLessEquals(below, epsilon: 2.5));
    });

    testWidgets('and on a taller one, where the leftover space grows', (
      tester,
    ) async {
      final (above, below) = await gaps(tester, surface: const Size(412, 960));

      expect(above, greaterThan(0));
      expect(above, moreOrLessEquals(below, epsilon: 2.5));
    });
  });

  group('MainScreen while no tunnel is up', () {
    // Not being connected is where the app rests, not news. The status line
    // under the dial says it once; a warning card above it said it again.
    testWidgets('should not warn that the address is in the open', (
      tester,
    ) async {
      await _pumpHomeUnderTheBar(tester, surface: const Size(393, 852));

      expect(find.byIcon(Iconsax.eye), findsNothing);
    });

    // How the connect will be made reads with the server it will use, under
    // the dial, rather than at the top of the screen.
    testWidgets('should put the connect settings in the server card', (
      tester,
    ) async {
      await _pumpHomeUnderTheBar(tester, surface: const Size(393, 852));

      expect(
        find.descendant(
          of: find.byType(HomeServerRow),
          matching: find.byType(HomeSettingsLine),
        ),
        findsOneWidget,
      );
    });

    // The settings line opens with a glyph of its own, and set under the
    // server's icon the card's two rows lead from one centre line.
    testWidgets('should centre the settings glyph under the server icon', (
      tester,
    ) async {
      await _pumpHomeUnderTheBar(tester, surface: const Size(393, 852));

      final server = tester.getCenter(
        find.descendant(
          of: find.byType(HomeServerRow),
          matching: find.byIcon(Iconsax.crown_1),
        ),
      );
      final settings = tester.getCenter(
        find.descendant(
          of: find.byType(HomeSettingsLine),
          matching: find.byType(Icon),
        ),
      );

      expect(settings.dx, moreOrLessEquals(server.dx, epsilon: 0.5));
    });
  });

  group('the reserve the screen keeps for the bar', () {
    testWidgets('leaves the row clear of it, inset and all', (tester) async {
      await _pumpHomeUnderTheBar(tester, surface: const Size(393, 852));

      final row = tester.getRect(find.byType(HomeServerRow));
      final barTop = tester.getRect(find.byType(NavBar)).top;

      expect(
        row.bottom,
        lessThan(barTop),
        reason: 'the server row would be drawn under the bar',
      );
    });
  });
}
