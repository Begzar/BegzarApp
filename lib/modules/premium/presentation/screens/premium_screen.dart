import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_devices_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_account_panel.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:begzar/modules/main/presentation/widgets/home_app_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The account tab: sign in, or manage the subscription that is signed in.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  /// Re-reads the subscription and devices when the tab is opened, so a change
  /// made on another device shows up without a manual refresh.
  static void refreshOnEnter(WidgetRef ref) {
    final state = ref.read(premiumProvider);
    if (state.isLoggedIn && !state.isLoggingOut) {
      ref.read(premiumProvider.notifier).refreshSubscription(silent: true);
      ref.read(premiumDevicesProvider.notifier).loadIfNeeded(force: true);
    }
  }

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PremiumScreen.refreshOnEnter(ref);
    });
  }

  /// Raises the error toast once, when the server takes this device's seat.
  ///
  /// Nothing the user pressed asked whether the seat was still theirs: the
  /// launch refresh, opening this tab or the device list finds out. This
  /// screen is built at launch whichever tab is showing, so it hears it from
  /// any of them. A deleted account ends the same way with no reason to give,
  /// and raises nothing.
  void _listenForRevokedSession() {
    ref.listen<PremiumState>(premiumProvider, (previous, next) {
      final wasRevoked = previous is PremiumSignedOut && previous.isRevoked;
      if (wasRevoked) return;
      if (next case PremiumSignedOut(isRevoked: true, :final errorMessage?)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showTopErrorPopup(context, errorMessage);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenForRevokedSession();
    ref.listen<bool>(premiumProvider.select((state) => state.isLoggedIn), (
      previous,
      next,
    ) {
      if (next == false) {
        ref.read(premiumDevicesProvider.notifier).reset();
        return;
      }
      if (previous == false && next == true) {
        ref.read(premiumDevicesProvider.notifier).loadIfNeeded(force: true);
      }
    });

    final palette = PremiumPalette.of(context);
    final premiumState = ref.watch(premiumProvider);
    final accent = _accentFor(palette, premiumState);
    // The tab stays built under the others, so its pass and spinners would
    // otherwise go on animating where nobody can see them.
    final showing = ref.watch(selectedTabProvider) == premiumIndex;

    return TickerMode(
      enabled: showing,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: palette.pageInk,
        // Ink, with the tab's blue lighting the top corner and a faint cool
        // light in the bottom one.
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const AlignmentDirectional(-1.2, 1.1),
              radius: 1.0,
              colors: palette.pageGlowLow,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const AlignmentDirectional(0.9, -1.1),
                radius: 1.1,
                colors: palette.pageGlow,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const HomeAppBar(),
                  Expanded(
                    // Only the launch restore stands in for the whole tab. A
                    // sign-in keeps the form on screen, its button saying so:
                    // the form reports its own refusal once the answer is in,
                    // and keeps what was typed for the next try.
                    child: premiumState is PremiumRestoring
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accent.primary,
                            ),
                          )
                        : SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              AppLayout.premiumScreenPadH.w,
                              AppLayout.premiumTabTopPad.h,
                              AppLayout.premiumScreenPadH.w,
                              NavBar.clearance.w,
                            ),
                            child: premiumState.isLoggedIn
                                ? _SignedInBody(
                                    state: premiumState,
                                    accent: accent,
                                  )
                                : PremiumLoginForm(
                                    state: premiumState,
                                    accent: accent,
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Read through the connect gate's own rule, so a disabled account is
  /// painted as one even when it has never paid.
  PremiumAccent _accentFor(PremiumPalette palette, PremiumState state) {
    final account = state.account;
    if (account == null) return PremiumAccent.signedOut(palette);
    return switch (PremiumConnectValidation.forAccount(account)) {
      PremiumConnectValidation.allowed => PremiumAccent.entitled(palette),
      // An account that has never paid is not in trouble, it has not started,
      // so it is not painted in the colour of a lapsed or disabled one.
      PremiumConnectValidation.notSubscribed => PremiumAccent.signedOut(
        palette,
      ),
      PremiumConnectValidation.accountInactive ||
      PremiumConnectValidation.subscriptionExpired ||
      PremiumConnectValidation.notLoggedIn ||
      PremiumConnectValidation.skipped ||
      PremiumConnectValidation.checkFailed => PremiumAccent.notEntitled(
        palette,
      ),
    };
  }
}

class _SignedInBody extends StatelessWidget {
  const _SignedInBody({required this.state, required this.accent});

  final PremiumState state;
  final PremiumAccent accent;

  @override
  Widget build(BuildContext context) {
    return PremiumAccountPanel(state: state, accent: accent);
  }
}
