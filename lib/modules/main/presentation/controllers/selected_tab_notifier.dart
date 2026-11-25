import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int homeIndex = 0;
const int premiumIndex = 1;
const int settingIndex = 2;

/// What analytics calls each tab. The tabs share one activity, so the SDK's
/// own screen tracking sees a single screen.
const _screenNames = {
  homeIndex: 'home',
  premiumIndex: 'premium',
  settingIndex: 'settings',
};

class SelectedTab extends Notifier<int> {
  void _recordShown(int index) {
    final screenName = _screenNames[index];
    if (screenName == null) return;
    unawaited(
      ref.read(analyticsServiceProvider).logScreenView(screenName: screenName),
    );
  }

  @override
  int build() {
    _recordShown(homeIndex);
    return homeIndex;
  }

  void select(int index) {
    if (state == index) return;
    state = index;
    _recordShown(index);
  }
}

/// Which root tab is showing.
///
/// Lives outside `RootScreen` so a flow that finishes on one tab can hand the
/// user to another — signing in happens on the premium tab but leaves the user
/// wanting the server list on home.
final selectedTabProvider = NotifierProvider<SelectedTab, int>(SelectedTab.new);
