import 'dart:async';

import 'package:begzar/modules/premium/application/services/google_play_purchase_service.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps Google Play purchases flowing for the whole run on a Play build.
///
/// The app shell starts it at launch. A pending payment can clear long after
/// the paywall closed, so the account is refreshed here, not on the paywall.
///
/// It publishes nothing. Riverpod drops a state equal to the one before it,
/// so two cancelled sheets in a row would reach a listener as one; the
/// paywall reads each outcome from the service's stream instead.
class PlayPurchaseNotifier extends Notifier<void> {
  late GooglePlayPurchaseService _service;

  void _onOutcome(PlayPurchaseOutcome outcome) {
    if (outcome != PlayPurchaseOutcome.granted) return;
    unawaited(
      ref.read(premiumProvider.notifier).refreshSubscription(silent: true),
    );
  }

  /// A purchase left unfinished for an account that was signed out at launch
  /// is only reported once that account signs in again, so a sign-in asks
  /// Play for it. The launch restore does not count: starting already asked.
  void _onPremium(PremiumState? previous, PremiumState next) {
    if (previous is PremiumSignedOut && next is PremiumSignedIn) {
      unawaited(_service.restore());
    }
  }

  @override
  void build() {
    _service = ref.watch(googlePlayPurchaseServiceProvider);
    final subscription = _service.outcomes.listen(_onOutcome);
    ref.onDispose(subscription.cancel);
    ref.listen(premiumProvider, _onPremium);
    unawaited(_service.start());
  }
}

/// Kept alive from launch for the rest of the run, on Play builds only.
final playPurchaseProvider = NotifierProvider<PlayPurchaseNotifier, void>(
  PlayPurchaseNotifier.new,
);
