import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/main/presentation/widgets/home_server_row.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wider than the 393 the row is designed for, because the font the test
/// binding substitutes draws every glyph as a fixed-width box and makes the
/// labels a good deal wider than any real font gives them. Every assertion
/// here is about which words and which side, never about a measurement, so the
/// extra room costs nothing and keeps the row off an overflow.
const _surface = Size(640, 200);

const _designSize = Size(393, 852);

/// Far enough out that nothing here depends on the clock drifting past it.
final _future = DateTime.now().add(const Duration(days: 30)).toIso8601String();
final _past = DateTime.now()
    .subtract(const Duration(days: 1))
    .toIso8601String();

/// The one server the resolved states point at.
const _server = PremiumServer(
  id: 7,
  name: 'Netherlands',
  configs: [
    PremiumServerConfig(id: 41, name: 'Amsterdam 01', url: 'vless://one'),
  ],
);

class _FixedConnection extends ConnectionNotifier {
  _FixedConnection(this.status);

  final ConnectionStatus status;

  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: status);
}

class _FixedPremium extends PremiumNotifier {
  _FixedPremium(this.value);

  final PremiumState value;

  @override
  PremiumState build() => value;
}

class _FixedServers extends PremiumServersNotifier {
  _FixedServers(this.value);

  final PremiumServersState value;

  @override
  PremiumServersState build() => value;
}

/// Signed in, with the subscription and status the case under test needs. No
/// [expireDate] is an account that has never paid.
PremiumState _signedIn({String? expireDate, String? statusLabel}) {
  return PremiumSignedIn(
    account: PremiumAccount(
      username: 'someone',
      expireDate: expireDate,
      statusLabel: statusLabel,
    ),
  );
}

void main() {
  late List<ConnectTapOutcome> refusals;
  late int pickerOpens;

  setUp(() {
    refusals = [];
    pickerOpens = 0;
  });

  Future<void> pumpRow(
    WidgetTester tester, {
    required PremiumState premium,
    PremiumServersState servers = const PremiumServersState(),
    ConnectionStatus status = ConnectionStatus.ready,
    Locale locale = const Locale('en'),
    Widget? footer,
  }) async {
    tester.view.physicalSize = _surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(() => _FixedConnection(status)),
          premiumProvider.overrideWith(() => _FixedPremium(premium)),
          premiumServersProvider.overrideWith(() => _FixedServers(servers)),
        ],
        child: ScreenUtilInit(
          designSize: _designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fa')],
            home: Scaffold(
              body: HomeServerRow(
                onOpenPicker: () => pickerOpens++,
                onRefused: refusals.add,
                footer: footer,
              ),
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the connecting state carries a CircularProgressIndicator,
    // which never settles. One frame to build, one past the row's own state
    // change, which is the only animation any of these cases has to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('an account short of premium is told which way out it has', () {
    // All three used to be reachable only by pressing the app bar's unlabelled
    // globe, which someone without a subscription has no reason to press. The
    // row says which of the three the account is in, and opens the dialog the
    // app already has for it — the outcome rather than the dialog, so the row
    // and the connect dial explain a refusal in the same words.
    testWidgets('no subscription offers premium', (tester) async {
      await pumpRow(tester, premium: const PremiumSignedOut());

      expect(find.text('Premium servers'), findsOneWidget);
      await tester.tap(find.byType(HomeServerRow));

      expect(refusals, [ConnectTapOutcome.notEntitled]);
      expect(pickerOpens, 0);
    });

    // An account created in the app has nothing to renew yet.
    testWidgets(
      'should offer premium, not a renewal, to a never-paid account',
      (tester) async {
        await pumpRow(tester, premium: _signedIn());

        expect(find.text('Premium servers'), findsOneWidget);
        expect(find.text('Subscription expired'), findsNothing);
        await tester.tap(find.byType(HomeServerRow));

        expect(refusals, [ConnectTapOutcome.notEntitled]);
      },
    );

    testWidgets('a lapsed subscription offers a renewal', (tester) async {
      await pumpRow(tester, premium: _signedIn(expireDate: _past));

      expect(find.text('Subscription expired'), findsOneWidget);
      await tester.tap(find.byType(HomeServerRow));

      expect(refusals, [ConnectTapOutcome.subscriptionExpired]);
    });

    testWidgets('a disabled account offers support', (tester) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future, statusLabel: 'disabled'),
      );

      expect(find.text('Account disabled'), findsOneWidget);
      await tester.tap(find.byType(HomeServerRow));

      expect(refusals, [ConnectTapOutcome.accountInactive]);
    });

    testWidgets('a disabled account is not read as a lapsed one', (
      tester,
    ) async {
      // Both are "not entitled", and an account can be disabled while its
      // subscription is still paid for. Renewing would not fix that one.
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future, statusLabel: 'disabled'),
      );

      expect(find.text('Subscription expired'), findsNothing);
    });
  });

  group('an entitled account is pointed at a server', () {
    testWidgets('asks to be tapped until the listing names one', (
      tester,
    ) async {
      // A relaunch that adopts a live tunnel knows its config id from storage
      // before the listing lands with the names, so there is a moment where
      // the row knows a config id and nothing to call it.
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        servers: const PremiumServersState(activeConfigId: 41),
        status: ConnectionStatus.connected,
      );

      expect(find.text('Choose a server'), findsOneWidget);
      expect(find.text('Amsterdam 01'), findsNothing);
    });

    testWidgets('should name the server and config while it is connected', (
      tester,
    ) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        servers: const PremiumServersState(
          servers: [_server],
          activeConfigId: 41,
          lastConnectedConfigId: 41,
          lastConnectedServerId: 7,
        ),
        status: ConnectionStatus.connected,
      );

      expect(find.text('Netherlands'), findsOneWidget);
      expect(find.text('Amsterdam 01'), findsOneWidget);
    });

    testWidgets('should name a connected server the list dropped, and say so', (
      tester,
    ) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        servers: const PremiumServersState(
          hasLoaded: true,
          activeConfigId: 41,
          activeLabel: PremiumServerLabel(
            serverName: 'Netherlands',
            configName: 'Amsterdam 01',
            flagCode: 'nl',
          ),
        ),
        status: ConnectionStatus.connected,
      );

      expect(find.text('Netherlands'), findsOneWidget);
      expect(find.text('Removed · pick another server'), findsOneWidget);
      expect(find.text('Choose a server'), findsNothing);
      expect(find.byType(PremiumServerIcon), findsOneWidget);

      // The hint asks for a new pick, so it wears the warning ink rather than
      // the quiet tone a config's name is set in.
      final palette = PremiumPalette.of(
        tester.element(find.byType(HomeServerRow)),
      );
      final hint = tester.widget<Text>(
        find.text('Removed · pick another server'),
      );
      expect(hint.style?.color, palette.amberInk);
    });

    testWidgets('should name the config picked from the list while it dials', (
      tester,
    ) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        servers: const PremiumServersState(
          servers: [_server],
          connectingConfigId: 41,
        ),
        status: ConnectionStatus.connecting,
      );

      expect(find.text('Netherlands'), findsOneWidget);
      expect(find.text('Amsterdam 01'), findsOneWidget);
    });

    testWidgets('should ask for a server once the tunnel is down', (
      tester,
    ) async {
      // The dial quick-connects across every server, so the one connected
      // last is not what a tap would use; naming it reads as a choice made.
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        servers: const PremiumServersState(
          servers: [_server],
          lastConnectedConfigId: 41,
          lastConnectedServerId: 7,
        ),
      );

      expect(find.text('Choose a server'), findsOneWidget);
      expect(find.text('Netherlands'), findsNothing);
      expect(find.byType(PremiumServerIcon), findsNothing);
    });

    testWidgets('opens the picker rather than explaining a refusal', (
      tester,
    ) async {
      await pumpRow(tester, premium: _signedIn(expireDate: _future));
      await tester.tap(find.byType(HomeServerRow));

      expect(pickerOpens, 1);
      expect(refusals, isEmpty);
    });
  });

  group('the row refuses a tap it has nothing stable to act on', () {
    // Mid-transition a tap would either open a picker onto a list about to
    // change under it, or raise a dialog over a connect still being waited on.
    for (final status in const [
      ConnectionStatus.connecting,
      ConnectionStatus.disconnecting,
    ]) {
      testWidgets('${status.name}: the tap does nothing', (tester) async {
        await pumpRow(
          tester,
          premium: _signedIn(expireDate: _future),
          status: status,
        );
        await tester.tap(find.byType(HomeServerRow));

        expect(pickerOpens, 0);
        expect(refusals, isEmpty);
      });
    }
  });

  // What the connect will use sits under the server it will use, in the same
  // card, so the two read as one answer to "what happens when I tap".
  group('HomeServerRow footer', () {
    const footerLabel = 'how the connect is made';

    testWidgets('should draw the footer inside the row\'s card', (
      tester,
    ) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        footer: const Text(footerLabel),
      );

      expect(
        find.descendant(
          of: find.byType(HomeServerRow),
          matching: find.text(footerLabel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('should not open the picker from the footer', (tester) async {
      await pumpRow(
        tester,
        premium: _signedIn(expireDate: _future),
        footer: const Text(footerLabel),
      );

      await tester.tap(find.text(footerLabel));

      expect(pickerOpens, 0);
      expect(refusals, isEmpty);
    });
  });

  group('the row follows the reading direction', () {
    // Like the app bar above it: a row that stayed left-to-right while
    // everything around it turned around reads as a row from another app.
    for (final (locale, offerLeads) in const [
      (Locale('en'), true),
      (Locale('fa'), false),
    ]) {
      testWidgets('${locale.languageCode}: the flag opens the reading', (
        tester,
      ) async {
        await pumpRow(
          tester,
          premium: _signedIn(expireDate: _future),
          servers: const PremiumServersState(
            servers: [_server],
            activeConfigId: 41,
          ),
          status: ConnectionStatus.connected,
          locale: locale,
        );

        final leading = tester.getRect(find.byType(PremiumServerIcon));
        final name = tester.getRect(find.text('Netherlands'));

        expect(leading.center.dx < name.center.dx, offerLeads);
      });
    }
  });
}
