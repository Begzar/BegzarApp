import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/states/force_update_state.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/screens/root_screen.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);

class _ReadyConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.ready);
}

class _SignedOutPremium extends PremiumNotifier {
  @override
  PremiumState build() => const PremiumSignedOut();
}

class _NoServers extends PremiumServersNotifier {
  @override
  PremiumServersState build() => const PremiumServersState();
}

class _NoForcedUpdate extends ForceUpdateNotifier {
  @override
  ForceUpdateState build() => const ForceUpdateState();
}

/// Records every `SystemNavigator.pop` the app asks the platform for.
List<String> _recordSystemNavigatorPops(WidgetTester tester) {
  final pops = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') pops.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return pops;
}

Future<ProviderContainer> _pumpRootScreen(WidgetTester tester) async {
  tester.view.physicalSize = _designSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      connectionProvider.overrideWith(_ReadyConnection.new),
      premiumProvider.overrideWith(_SignedOutPremium.new),
      premiumServersProvider.overrideWith(_NoServers.new),
      forceUpdateProvider.overrideWith(_NoForcedUpdate.new),
      ipInfoProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
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
          home: const RootScreen(),
        ),
      ),
    ),
  );

  // Not pumpAndSettle: the home dial breathes on a loop that never finishes.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  group('RootScreen back press', () {
    testWidgets('should close the app on the home tab', (tester) async {
      final pops = _recordSystemNavigatorPops(tester);
      await _pumpRootScreen(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(pops, ['SystemNavigator.pop']);
    });

    testWidgets('should return to home from another tab without closing', (
      tester,
    ) async {
      final pops = _recordSystemNavigatorPops(tester);
      final container = await _pumpRootScreen(tester);
      container.read(selectedTabProvider.notifier).select(settingIndex);
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(container.read(selectedTabProvider), homeIndex);
      expect(pops, isEmpty);
    });
  });
}
