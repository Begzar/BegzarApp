import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';

/// What came of a tap on Subscribe.
enum PaywallSubscribe {
  /// Play's sheet is open, or already was.
  started,

  /// Nobody is signed in. The plan is remembered for after the sign-in.
  needsSignIn,

  /// Play's sheet would not open.
  refused,
}

/// The paywall's state: what Play sells here, what is selected, and how the
/// last purchase went.
final class PremiumPaywallState {
  const PremiumPaywallState({
    this.isLoading = true,
    this.offers = const {},
    this.devices = defaultDevices,
    this.months = defaultMonths,
    this.isPurchasing = false,
    this.outcome,
  });

  /// The device count the paywall opens on when nothing else was asked for,
  /// or the fewest Play sells when it does not sell this many. The period it
  /// opens on is decided from the prices once they load.
  static const defaultDevices = 3;

  /// What [months] holds before the prices have loaded.
  static const defaultMonths = 1;

  final bool isLoading;

  /// Offers by device count, fewest devices first, each count's periods
  /// shortest first.
  final Map<int, List<PremiumPlanOffer>> offers;

  final int devices;
  final int months;

  /// True from the tap on Subscribe until Play reports how it went.
  final bool isPurchasing;

  /// How the last purchase went, while there is something to tell the buyer
  /// about it. A closed sheet leaves nothing to tell.
  final PlayPurchaseOutcome? outcome;

  /// Nothing to sell: Play is missing or knows none of the plans, or the
  /// plans could not be read.
  bool get isUnavailable => !isLoading && offers.isEmpty;

  /// The periods offered for the selected device count.
  List<PremiumPlanOffer> get periods => offers[devices] ?? const [];

  PremiumPlanOffer? get selected =>
      periods.where((offer) => offer.months == months).firstOrNull;

  PremiumPaywallState copyWith({
    bool? isLoading,
    Map<int, List<PremiumPlanOffer>>? offers,
    int? devices,
    int? months,
    bool? isPurchasing,
    PlayPurchaseOutcome? outcome,
    bool clearOutcome = false,
  }) {
    return PremiumPaywallState(
      isLoading: isLoading ?? this.isLoading,
      offers: offers ?? this.offers,
      devices: devices ?? this.devices,
      months: months ?? this.months,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
    );
  }
}
