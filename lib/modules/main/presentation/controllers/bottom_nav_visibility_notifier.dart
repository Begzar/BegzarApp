import 'package:flutter_riverpod/flutter_riverpod.dart';

class HideBottomNav extends Notifier<bool> {
  int _modalCount = 0;

  @override
  bool build() => false;

  void onModalOpened() {
    _modalCount++;
    if (!state) {
      state = true;
    }
  }

  void onModalClosed() {
    _modalCount = (_modalCount - 1).clamp(0, 100);
    if (_modalCount == 0 && state) {
      state = false;
    }
  }
}

/// Hides the root bottom navigation bar while modal overlays are open.
final hideBottomNavProvider = NotifierProvider<HideBottomNav, bool>(
  HideBottomNav.new,
);
