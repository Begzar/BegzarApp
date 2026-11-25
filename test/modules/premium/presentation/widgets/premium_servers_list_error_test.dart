import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_servers_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

/// A connection whose status the test drives directly.
///
/// `ConnectionNotifier.build` only reads three providers and returns a fresh
/// entity, so replacing it keeps the real tunnel services out of a widget test.
class _DrivenConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() => const ConnectionEntity.create();

  void fail(String errorKey) => state = state.failed(errorKey);
}

/// A list that is already loaded, and never asks the network for more.
class _LoadedServers extends PremiumServersNotifier {
  @override
  PremiumServersState build() => const PremiumServersState(
    hasLoaded: true,
    servers: [
      PremiumServer(
        id: 1,
        name: 'Alpha',
        configs: [
          PremiumServerConfig(id: 1, name: 'Main', url: 'test://alpha'),
        ],
      ),
    ],
  );

  @override
  Future<void> load({bool force = false}) async {}
}

/// A list that has nothing yet, and fails when the test says so.
class _FailingServers extends PremiumServersNotifier {
  @override
  PremiumServersState build() => const PremiumServersState(hasLoaded: true);

  @override
  Future<void> load({bool force = false}) async {}

  void fail(String errorKey) => state = state.copyWith(errorMessage: errorKey);
}

Widget _listUnderTest(ProviderContainer container, {ThemeData? theme}) {
  return UncontrolledProviderScope(
    container: container,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: theme,
        // The same four the app declares in app.dart. Dropping the Cupertino
        // one passes for English and throws the moment a test asks for fa.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fa')],
        home: const Scaffold(body: PremiumServersList()),
      ),
    ),
  );
}

void main() {
  late ProviderContainer container;

  ProviderContainer buildContainer({
    required PremiumServersNotifier Function() servers,
  }) {
    final built = ProviderContainer(
      overrides: [
        connectionProvider.overrideWith(_DrivenConnection.new),
        premiumServersProvider.overrideWith(servers),
      ],
    );
    addTearDown(built.dispose);
    return built;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PremiumServersList)));

  group('PremiumServersList', () {
    testWidgets('should leave a failed connect to the toast', (tester) async {
      container = buildContainer(servers: _LoadedServers.new);
      await tester.pumpWidget(_listUnderTest(container));
      await tester.pumpAndSettle();

      (container.read(connectionProvider.notifier) as _DrivenConnection).fail(
        UserFacingErrorKeys.connectionFailed,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10nOf(tester).translateError(UserFacingErrorKeys.connectionFailed),
        ),
        findsNothing,
        reason:
            'the home screen raises the toast for a failed connect, and a '
            'notice in the list repeating it showed the same error twice',
      );
    });

    group('a list that failed to load', () {
      /// Pumps an empty list, fails its load, and lets the toast slide in.
      Future<AppLocalizations> failLoadWith(
        WidgetTester tester,
        String errorKey,
      ) async {
        container = buildContainer(servers: _FailingServers.new);
        await tester.pumpWidget(_listUnderTest(container));
        await tester.pumpAndSettle();

        (container.read(premiumServersProvider.notifier) as _FailingServers)
            .fail(errorKey);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        return l10nOf(tester);
      }

      testWidgets('should say why once, in the toast', (tester) async {
        final l10n = await failLoadWith(
          tester,
          UserFacingErrorKeys.loadPremiumServers,
        );
        final reason = l10n.translateError(
          UserFacingErrorKeys.loadPremiumServers,
        );

        expect(
          find.text(reason),
          findsOneWidget,
          reason: 'the empty list used to print the toast\'s message again',
        );

        await tester.pump(_pastTheToast);
        expect(find.text(reason), findsNothing);
      });

      testWidgets('should keep the way to try again', (tester) async {
        final l10n = await failLoadWith(
          tester,
          UserFacingErrorKeys.loadPremiumServers,
        );

        await tester.pump(_pastTheToast);

        expect(
          find.text(l10n.tryAgain),
          findsOneWidget,
          reason:
              'the toast goes, and an empty list with no way to ask again '
              'would leave reopening the sheet as the only retry',
        );
      });

      // The label was the page's text colour, which on a light page is the
      // dark ink: on the blue button it read near 2:1.
      testWidgets('should label try again in the ink its fill takes in light', (
        tester,
      ) async {
        container = buildContainer(servers: _FailingServers.new);
        await tester.pumpWidget(
          _listUnderTest(
            container,
            theme: AppTheme.light(fontFamily: 'Roboto'),
          ),
        );
        await tester.pumpAndSettle();
        (container.read(premiumServersProvider.notifier) as _FailingServers)
            .fail(UserFacingErrorKeys.loadPremiumServers);
        await tester.pump();
        await tester.pump(_pastTheToast);

        final fill = const PremiumPalette(AppPalette.light).primary;
        final label = tester
            .renderObject<RenderParagraph>(find.text(l10nOf(tester).tryAgain))
            .text
            .style
            ?.color;
        expect(label, AppPalette.labelOn(fill));
      });

      testWidgets('should offer support once, in the toast', (tester) async {
        final l10n = await failLoadWith(
          tester,
          UserFacingErrorKeys.deviceLimit,
        );

        expect(find.text(l10n.getHelp), findsOneWidget);

        await tester.pump(_pastTheToast);
      });
    });
  });
}
