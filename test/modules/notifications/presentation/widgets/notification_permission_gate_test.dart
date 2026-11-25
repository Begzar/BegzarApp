import 'dart:async';

import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/notifications/data/datasources/notification_permission_service.dart';
import 'package:begzar/modules/notifications/presentation/widgets/notification_permission_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);
const _home = Key('home');

/// A permission the platform has not answered about yet.
class _UnansweredPermission implements NotificationPermissionService {
  final _answer = Completer<bool>();

  @override
  Future<bool> isGranted() => _answer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A permission the reader has not given, which the system can still ask for.
class _RefusedPermission implements NotificationPermissionService {
  @override
  Future<bool> isGranted() async => false;

  @override
  Future<bool> shouldOpenSettings() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pumpGate(
  WidgetTester tester,
  NotificationPermissionService permission,
) async {
  tester.view
    ..physicalSize = _designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      launchCoverProvider.overrideWith(
        () => LaunchCoverNotifier(initial: LaunchCoverPhase.covering),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationPermissionGate(
            permissionService: permission,
            child: const SizedBox(key: _home),
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  group('NotificationPermissionGate', () {
    // The check runs on every launch, between the launch window and home; a
    // spinner on the platform's default white flashed in that gap.
    testWidgets('should draw the bare page while the platform answers', (
      tester,
    ) async {
      await _pumpGate(tester, _UnansweredPermission());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final page = tester.widget<ColoredBox>(
        find.byKey(NotificationPermissionGate.waitingKey),
      );
      expect(page.color, AppPalette.dark.page);
    });

    testWidgets('should leave the launch cover up while the platform answers', (
      tester,
    ) async {
      final container = await _pumpGate(tester, _UnansweredPermission());

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.covering,
      );
    });

    testWidgets('should end the launch cover when it has to ask', (
      tester,
    ) async {
      final container = await _pumpGate(tester, _RefusedPermission());
      await tester.pump();

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });
  });
}
