import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/controllers/pending_premium_plan_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hands a user who has just signed in over to the home screen.
///
/// Signing in happens on the premium tab, which afterwards shows only the
/// subscription card — so without this the user is left on a screen that says
/// nothing about what to do next.
///
/// It used to wait for the premium server list to finish loading before making
/// the move, because home *was* that list and arriving on a spinner was worse
/// than arriving late. Home is the connect dial now, which is worth arriving on
/// straight away; the server row above it names its server as soon as the
/// listing lands, and the listing is fetched by the entitlement change itself
/// rather than by anything here.
///
/// On a Play build it also carries a buyer the paywall sent to sign in: to the
/// premium tab, where the form is, and back to the paywall on the plan they
/// had chosen once the sign-in lands on an account with nothing to use.
///
/// A mixin on the root screen's state rather than a notifier: it is one
/// listener, and the thing it acts on is which tab is showing.
mixin SignInHandoff<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void _onPlanRemembered(PremiumPlan? previous, PremiumPlan? next) {
    if (next == null) return;
    ref.read(selectedTabProvider.notifier).select(premiumIndex);
  }

  /// Reopens the paywall on [plan] for an account that can buy. A disabled
  /// one cannot use what it would pay for; support answers that, not a sale.
  void _resumePurchase(PremiumSignedIn signedIn, PremiumPlan plan) {
    final standing = PremiumConnectValidation.forAccount(signedIn.account);
    if (standing != PremiumConnectValidation.notSubscribed &&
        standing != PremiumConnectValidation.subscriptionExpired) {
      return;
    }
    showPremiumPaywall(
      context,
      renewal: standing == PremiumConnectValidation.subscriptionExpired,
      selecting: plan,
    );
  }

  void _onPremiumChanged(PremiumState? previous, PremiumState next) {
    // Only an interactive sign-in comes from PremiumSignedOut; restoring a
    // stored session on launch comes from PremiumRestoring, and must not
    // yank the user to the home tab.
    if (previous is! PremiumSignedOut || next is! PremiumSignedIn) return;

    // Taken whatever the account turns out to be, so it is offered once.
    final plan = ref.read(pendingPremiumPlanProvider.notifier).take();
    if (next.isEntitled) {
      ref.read(selectedTabProvider.notifier).select(homeIndex);
      return;
    }
    if (plan != null && mounted) _resumePurchase(next, plan);
  }

  /// Call from `build`. Riverpod deduplicates the subscription, so it is safe
  /// on every rebuild.
  void listenForSignInHandoff() {
    ref.listen<PremiumState>(premiumProvider, _onPremiumChanged);
    ref.listen<PremiumPlan?>(pendingPremiumPlanProvider, _onPlanRemembered);
  }
}
