import 'package:begzar/modules/main/presentation/controllers/bottom_nav_visibility_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks modal routes (bottom sheets, dialogs) and hides the root bottom nav.
/// Each tab navigator must use its own observer instance.
class BottomNavModalObserver extends NavigatorObserver {
  BottomNavModalObserver(this.ref);

  final WidgetRef ref;

  void _onModalPushed() {
    ref.read(hideBottomNavProvider.notifier).onModalOpened();
  }

  void _onModalPopped() {
    ref.read(hideBottomNavProvider.notifier).onModalClosed();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute) {
      _onModalPushed();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PopupRoute) {
      _onModalPopped();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PopupRoute) {
      _onModalPopped();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PopupRoute) _onModalPopped();
    if (newRoute is PopupRoute) _onModalPushed();
  }
}
