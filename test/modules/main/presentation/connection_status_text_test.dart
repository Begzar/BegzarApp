import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_status_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The status line under the dial, with nothing else on screen.
///
/// It takes the connection it reads as an argument, so this needs no provider
/// container: what it says is a function of that connection, and that is
/// exactly what is being pinned here. [platform] stands in for the device, and
/// null leaves the one the test runs as.
Widget _statusUnderTest({
  required ConnectionEntity connection,
  TargetPlatform? platform,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: ThemeData(platform: platform),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fa')],
      home: Scaffold(body: ConnectionStatusText(connection: connection)),
    ),
  );
}

/// A tunnel that came up [ago] before now.
///
/// The half second is slack, not decoration: the clock truncates, so a
/// connection stamped exactly 14:07 ago reads as 14:07 only until the machine
/// running the test spends a second getting to the first frame.
ConnectionEntity _upFor(Duration ago) => ConnectionEntity(
  status: ConnectionStatus.connected,
  connectedAt: DateTime.now().subtract(ago + const Duration(milliseconds: 500)),
);

const _fourteenSeven = Duration(minutes: 14, seconds: 7);

/// The clock, whatever it currently reads.
///
/// The reading is taken from the wall clock, so a test that watches it move
/// cannot name both readings up front — it matches the shape and compares.
final _anyClock = find.bySemanticsLabel(RegExp(r'^\d{2}:\d{2}:\d{2}$'));

void main() {
  /// Pumps the line and hands back the localizations it was built with, so a
  /// test names the string it expects rather than repeating the copy.
  Future<AppLocalizations> pumpStatus(
    WidgetTester tester, {
    required ConnectionEntity connection,
    TargetPlatform? platform,
  }) async {
    await tester.pumpWidget(
      _statusUnderTest(connection: connection, platform: platform),
    );
    await tester.pumpAndSettle();

    return AppLocalizations.of(
      tester.element(find.byType(ConnectionStatusText)),
    );
  }

  testWidgets('says what to do next while ready', (tester) async {
    final l10n = await pumpStatus(
      tester,
      connection: const ConnectionEntity.create(),
    );

    expect(
      find.text(l10n.connectionSubtitle('ready', defaultTargetPlatform)),
      findsOneWidget,
    );
  });

  testWidgets('a desktop is asked to click rather than tap', (tester) async {
    final l10n = await pumpStatus(
      tester,
      connection: const ConnectionEntity.create(),
      platform: TargetPlatform.macOS,
    );

    expect(find.text(l10n.connSub_readyDesktop), findsOneWidget);
    expect(find.text(l10n.connSub_ready), findsNothing);
  });

  testWidgets('a phone is asked to tap rather than click', (tester) async {
    final l10n = await pumpStatus(
      tester,
      connection: const ConnectionEntity.create(),
      platform: TargetPlatform.android,
    );

    expect(find.text(l10n.connSub_ready), findsOneWidget);
    expect(find.text(l10n.connSub_readyDesktop), findsNothing);
  });

  testWidgets('a failure with no reason asks a desktop to click again', (
    tester,
  ) async {
    final l10n = await pumpStatus(
      tester,
      connection: const ConnectionEntity(status: ConnectionStatus.error),
      platform: TargetPlatform.windows,
    );

    expect(find.text(l10n.connSub_errorDesktop), findsOneWidget);
    expect(find.text(l10n.connSub_error), findsNothing);
  });

  group('ConnectionStatusText', () {
    // At rest the hint is the way in, so it wears the accent the app gives its
    // primary action; the title above it stays the one plain statement.
    testWidgets('should draw the ready hint in the accent', (tester) async {
      final l10n = await pumpStatus(
        tester,
        connection: const ConnectionEntity.create(),
        platform: TargetPlatform.android,
      );

      expect(
        tester.widget<Text>(find.text(l10n.connSub_ready)).style?.color,
        isSameColorAs(AppPalette.dark.accent),
      );
    });

    // Once a connect is under way the hint is news, not an invitation, and
    // the accent belongs to the tunnel that is coming.
    testWidgets('should keep the connecting hint in the body ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        _statusUnderTest(
          connection: const ConnectionEntity(
            status: ConnectionStatus.connecting,
          ),
          platform: TargetPlatform.android,
        ),
      );
      await tester.pump();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ConnectionStatusText)),
      );

      expect(
        tester.widget<Text>(find.text(l10n.connSub_connecting)).style?.color,
        isSameColorAs(const MainPalette(AppPalette.dark).idle),
      );
    });

    testWidgets('should ask for another try instead of repeating the reason', (
      tester,
    ) async {
      final l10n = await pumpStatus(
        tester,
        connection: const ConnectionEntity.create().failed(
          UserFacingErrorKeys.noWorkingConfig,
        ),
        platform: TargetPlatform.android,
      );

      expect(find.text(l10n.connSub_error), findsOneWidget);
      expect(
        find.text(l10n.translateError(UserFacingErrorKeys.noWorkingConfig)),
        findsNothing,
        reason:
            'the error toast is what says why a connect failed; the line '
            'under the dial repeating it showed the same error twice',
      );
    });
  });

  testWidgets('a live tunnel says how long it has been up', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _statusUnderTest(connection: _upFor(_fourteenSeven)),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('00:14:07'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('the clock moves on its own, without the connection changing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _statusUnderTest(connection: _upFor(_fourteenSeven)),
    );
    await tester.pump();

    final first = tester.getSemantics(_anyClock).label;

    // A real second has to pass, not a pumped one: the reading is taken from
    // the wall clock the tunnel was stamped against, which no test binding
    // fakes. The pump after it is what lets the widget's own ticker fire.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.getSemantics(_anyClock).label,
      isNot(first),
      reason:
          'nothing about the connection changed, so only this widget can '
          'have moved the reading on',
    );
    expect(
      _anyClock,
      findsOneWidget,
      reason:
          'a tick reprints the line in place; a second clock here would mean '
          'the key moved with the text and the line slides once a second',
    );

    semantics.dispose();
  });

  testWidgets('the clock counts in Persian digits', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          locale: const Locale('fa'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fa')],
          home: Scaffold(
            body: ConnectionStatusText(connection: _upFor(_fourteenSeven)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('۰۰:۱۴:۰۷'), findsOneWidget);

    semantics.dispose();
  });
}
