import 'package:begzar/modules/ads/presentation/controllers/ad_overlay_back_handler.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/bottom_nav_visibility_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/sign_in_handoff.dart';
import 'package:begzar/modules/main/presentation/observers/bottom_nav_modal_observer.dart';
import 'package:begzar/modules/main/presentation/screens/main_screen.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/other_vpn_alerts.dart';
import 'package:begzar/modules/premium/presentation/screens/premium_screen.dart';
import 'package:begzar/modules/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The three tabs and the bar that switches them.
///
/// Each tab keeps its own [Navigator] inside an [IndexedStack], so switching
/// tabs preserves where the user was in each one.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> with SignInHandoff {
  final _navigatorKeys = {
    homeIndex: GlobalKey<NavigatorState>(),
    premiumIndex: GlobalKey<NavigatorState>(),
    settingIndex: GlobalKey<NavigatorState>(),
  };

  /// One observer per tab: a modal opened in one tab must not be counted
  /// against another's navigator.
  late final _modalObservers = {
    for (final index in _navigatorKeys.keys) index: BottomNavModalObserver(ref),
  };

  /// Back pops within the current tab first, and only then returns to home.
  /// On home, back leaves the app.
  ///
  /// Anything covering the whole app answers first. The ad overlays are painted
  /// above the router, where a `PopScope` of their own would register with no
  /// route and never fire, so this route's is the only one the press reaches —
  /// and a press aimed at an overlay must not move the tabs underneath it.
  void _handleBack() {
    if (ref.read(adOverlayBackHandlerProvider).handleBack()) return;

    final selected = ref.read(selectedTabProvider);
    final navigator = _navigatorKeys[selected]!.currentState!;

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (selected != homeIndex) {
      ref.read(selectedTabProvider.notifier).select(homeIndex);
      return;
    }

    // This scope never lets a pop through, so leaving the app is asked for.
    SystemNavigator.pop();
  }

  void _selectTab(int index) {
    ref.read(selectedTabProvider.notifier).select(index);
    // Entering the premium tab re-asks the server what the subscription is
    // worth, so the card is never showing a stale answer.
    if (index == premiumIndex) PremiumScreen.refreshOnEnter(ref);
  }

  /// Raises what the other-VPN check found, over whichever tab is showing:
  /// the home dial asks before a connect, and the premium list before it
  /// measures a server.
  void _listenForOtherVpn() {
    ref.listen(otherVpnProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showOtherVpnAlert(context, ref, next.verdict);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    listenForSignInHandoff();
    _listenForOtherVpn();

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final hideBottomNav = ref.watch(hideBottomNavProvider);
    final selected = ref.watch(selectedTabProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            IndexedStack(
              index: selected,
              children: [
                _tab(homeIndex, const MainScreen()),
                _tab(premiumIndex, const PremiumScreen()),
                _tab(settingIndex, const SettingsScreen()),
              ],
            ),
            // The bar floats over the tabs, so it hides for anything that
            // needs the room: a keyboard, or a modal covering the screen.
            if (!keyboardVisible && !hideBottomNav)
              Positioned(
                bottom:
                    NavBar.bottomInset.w + MediaQuery.paddingOf(context).bottom,
                left: 0,
                right: 0,
                child: NavBar(selected: selected, onSelect: _selectTab),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_modalObservers[index]!],
      pages: [
        MaterialPage(
          key: ValueKey('tab-$index-${child.runtimeType}'),
          child: child,
        ),
      ],
      onDidRemovePage: (page) {
        // Single-page tab navigator; the parent rebuilds `pages`.
      },
    );
  }
}
