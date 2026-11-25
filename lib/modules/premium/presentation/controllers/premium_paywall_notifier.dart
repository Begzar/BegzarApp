import 'dart:async';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/premium/application/services/google_play_purchase_service.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/controllers/pending_premium_plan_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/play_purchase_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_paywall_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

/// Drives the paywall on a Play build: which plan is selected, and the one
/// purchase a tap on Subscribe starts.
class PremiumPaywallNotifier extends Notifier<PremiumPaywallState> {
  static const _log = Log('premium');
  static const _defaultDevices = PremiumPaywallState.defaultDevices;

  late GooglePlayPurchaseService _service;
  late AnalyticsService _analytics;

  /// Records how the purchase of the selected plan ended. No revenue rides
  /// along: Play reports a sale itself, as `in_app_purchase`.
  void _recordResult(PlayPurchaseOutcome outcome) {
    final offer = state.selected;
    if (offer == null) return;
    unawaited(
      _analytics.logPlayPurchaseResult(
        outcome: outcome.name,
        devices: offer.plan.devices,
        months: offer.months,
      ),
    );
  }

  /// Only a purchase this paywall started is its news: a restore at launch
  /// or after a sign-in reports purchases it never made. One it started
  /// that is still clearing is followed to its end.
  void _onOutcome(PlayPurchaseOutcome outcome) {
    final awaiting =
        state.isPurchasing || state.outcome == PlayPurchaseOutcome.pending;
    if (!awaiting) return;
    _recordResult(outcome);
    state = outcome == PlayPurchaseOutcome.canceled
        ? state.copyWith(isPurchasing: false, clearOutcome: true)
        : state.copyWith(isPurchasing: false, outcome: outcome);
  }

  @override
  PremiumPaywallState build() {
    // The shell starts the listener at launch; watching it here as well means
    // a purchase made from the paywall always has someone to see it through.
    ref.watch(playPurchaseProvider);
    _service = ref.watch(googlePlayPurchaseServiceProvider);
    _analytics = ref.watch(analyticsServiceProvider);
    final subscription = _service.outcomes.listen(_onOutcome);
    ref.onDispose(subscription.cancel);
    return const PremiumPaywallState();
  }

  /// [months] when [devices] is offered for it, that count's shortest period
  /// otherwise.
  int _monthsFor(
    Map<int, List<PremiumPlanOffer>> offers,
    int devices,
    int months,
  ) {
    final periods = offers[devices] ?? const <PremiumPlanOffer>[];
    if (periods.any((offer) => offer.months == months)) return months;
    return periods.firstOrNull?.months ?? months;
  }

  /// Reads what Play sells here and selects [selecting] when it is among it.
  /// Otherwise it opens on [PremiumPaywallState.defaultDevices] — the fewest
  /// sold, when Play does not sell that many — and the period that costs it
  /// least a month, which the page marks as the best value, or the shortest
  /// period when no period saves anything.
  Future<void> load({PremiumPlan? selecting}) async {
    final result = await _service.loadOffers();
    if (!ref.mounted) return;

    final List<PremiumPlanOffer> loaded;
    switch (result) {
      case Left(value: final failure):
        _log.warn('paywall.load.refused', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        loaded = const [];
      case Right(value: final offers):
        loaded = offers;
    }

    final offers = offersByDevices(loaded);
    final wanted = loaded.where((offer) => offer.plan == selecting).firstOrNull;
    final devices =
        wanted?.plan.devices ??
        (offers.containsKey(_defaultDevices)
            ? _defaultDevices
            : offers.firstKey() ?? _defaultDevices);
    final periods = offers[devices] ?? const <PremiumPlanOffer>[];
    state = state.copyWith(
      isLoading: false,
      offers: offers,
      devices: devices,
      months:
          wanted?.months ??
          bestValue(periods)?.months ??
          periods.firstOrNull?.months,
    );
    unawaited(_analytics.logPaywallOpened(plans: loaded.length));
  }

  /// Keeps the selected period when [devices] offers it.
  void selectDevices(int devices) {
    if (state.isPurchasing || !state.offers.containsKey(devices)) return;
    state = state.copyWith(
      devices: devices,
      months: _monthsFor(state.offers, devices, state.months),
      clearOutcome: true,
    );
  }

  void selectMonths(int months) {
    if (state.isPurchasing) return;
    if (!state.periods.any((offer) => offer.months == months)) return;
    state = state.copyWith(months: months, clearOutcome: true);
  }

  /// Opens Play's sheet, reading a throw — a flow already open, a billing
  /// client that dropped — as a sheet that would not open.
  Future<bool> _openPlay(PremiumPlan plan) async {
    try {
      return await _service.buy(plan);
    } catch (error) {
      _log.warn('paywall.buy.threw', {'type': error.runtimeType});
      return false;
    }
  }

  /// Buys the selected plan. A tap that lands while a purchase is under way
  /// starts nothing; the first one's outcome answers both.
  Future<PaywallSubscribe> subscribe() async {
    final offer = state.selected;
    if (offer == null) return PaywallSubscribe.refused;
    if (state.isPurchasing) return PaywallSubscribe.started;
    // Before the first await, so a second tap finds it.
    state = state.copyWith(isPurchasing: true, clearOutcome: true);

    // A launch restore that has not landed yet reads as signed out.
    await ref.read(premiumProvider.notifier).ensureRestored();
    if (!ref.mounted) return PaywallSubscribe.refused;
    if (ref.read(premiumProvider).account == null) {
      ref.read(pendingPremiumPlanProvider.notifier).remember(offer.plan);
      state = state.copyWith(isPurchasing: false);
      return PaywallSubscribe.needsSignIn;
    }

    _log.trace('paywall.subscribe', {
      'devices': offer.plan.devices,
      'months': offer.months,
    });
    final opened = await _openPlay(offer.plan);
    if (opened) {
      unawaited(
        _analytics.logBeginCheckout(
          devices: offer.plan.devices,
          months: offer.months,
        ),
      );
      return PaywallSubscribe.started;
    }
    _recordResult(PlayPurchaseOutcome.failed);
    if (ref.mounted) {
      state = state.copyWith(
        isPurchasing: false,
        outcome: PlayPurchaseOutcome.failed,
      );
    }
    return PaywallSubscribe.refused;
  }
}

/// Auto-disposed, so each opening of the paywall reads Play's prices afresh.
final premiumPaywallProvider =
    NotifierProvider.autoDispose<PremiumPaywallNotifier, PremiumPaywallState>(
      PremiumPaywallNotifier.new,
    );
