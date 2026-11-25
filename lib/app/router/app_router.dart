import 'package:begzar/core/navigation/root_navigator_key.dart';
import 'package:begzar/modules/notifications/presentation/widgets/notification_permission_gate.dart';
import 'package:begzar/modules/main/presentation/screens/root_screen.dart';
import 'package:begzar/modules/settings/presentation/widgets/first_run_language_gate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/main/presentation/screens/main_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // Straight to the app. The only thing the old splash route did that the
    // app still needs is the version check, and that now runs from startup
    // without a screen of its own — the native splash covers the launch.
    initialLocation: '/root',
    routes: [
      // Language first, so the permission request after it is already in
      // the language the reader picked.
      GoRoute(
        path: '/root',
        builder: (context, state) => const FirstRunLanguageGate(
          child: NotificationPermissionGate(child: RootScreen()),
        ),
      ),

      GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
    ],
  );
});
