import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The plan a signed-out buyer picked on the paywall, held until a sign-in
/// can buy it.
///
/// A purchase has to land on an account, so the paywall sends a signed-out
/// buyer to sign in first; this is what lets the paywall reopen on the plan
/// they had chosen rather than start them over.
class PendingPremiumPlanNotifier extends Notifier<PremiumPlan?> {
  @override
  PremiumPlan? build() => null;

  /// Every remember is a request to sign in, the same plan twice included:
  /// Riverpod would otherwise drop the second as no change, and the root
  /// screen would not move to the sign-in form.
  @override
  bool updateShouldNotify(PremiumPlan? previous, PremiumPlan? next) => true;

  void remember(PremiumPlan plan) => state = plan;

  /// Hands the plan over and forgets it, so it is offered once.
  PremiumPlan? take() {
    final plan = state;
    state = null;
    return plan;
  }
}

/// Kept alive: the buyer leaves the paywall to sign in, and the plan has to
/// outlive it.
final pendingPremiumPlanProvider =
    NotifierProvider<PendingPremiumPlanNotifier, PremiumPlan?>(
      PendingPremiumPlanNotifier.new,
    );
