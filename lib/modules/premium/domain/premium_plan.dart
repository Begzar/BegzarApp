import 'dart:collection';

/// One subscription the paywall can sell: a device count for a billing
/// period, named by the Play product and base plan that sell it.
///
/// The catalogue comes from the server, so Play Console can change without a
/// release; the price never does — Play answers it in the buyer's currency.
class PremiumPlan {
  const PremiumPlan({
    required this.devices,
    required this.productId,
    required this.basePlanId,
  });

  /// How many devices the subscription lets sign in at once.
  final int devices;

  final String productId;
  final String basePlanId;

  @override
  bool operator ==(Object other) =>
      other is PremiumPlan &&
      other.devices == devices &&
      other.productId == productId &&
      other.basePlanId == basePlanId;

  @override
  int get hashCode => Object.hash(devices, productId, basePlanId);
}

/// A plan with what Play says it costs here, for how long.
class PremiumPlanOffer {
  const PremiumPlanOffer({
    required this.plan,
    required this.price,
    required this.months,
    required this.priceMicros,
    required this.currencyCode,
  });

  final PremiumPlan plan;

  /// Play's own formatted price, in the buyer's currency.
  final String price;

  final int months;

  /// The same price as a number, in millionths of [currencyCode], for working
  /// out what a month costs. Play's [price] is still what the buyer is shown
  /// as the total.
  final int priceMicros;

  /// ISO 4217, as Play reports it.
  final String currencyCode;

  int get perMonthMicros => priceMicros ~/ months;

  @override
  bool operator ==(Object other) =>
      other is PremiumPlanOffer &&
      other.plan == plan &&
      other.price == price &&
      other.months == months &&
      other.priceMicros == priceMicros &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode =>
      Object.hash(plan, price, months, priceMicros, currencyCode);
}

/// The billing periods the paywall sells, as Play writes them in ISO 8601.
const _monthsInPeriod = {'P1M': 1, 'P3M': 3, 'P6M': 6, 'P1Y': 12};

/// Months in a billing period Play reports, or null for one the paywall does
/// not sell — a weekly plan has no row to go in.
int? billingPeriodMonths(String isoPeriod) => _monthsInPeriod[isoPeriod];

/// What [offer] saves a month against the monthly plan among [periods], in
/// whole percent rounded down, so the paywall never claims more than the
/// buyer saves. Null when there is nothing honest to say: no monthly plan
/// for the same device count, a different currency, or no saving at all.
int? savingsPercent(
  PremiumPlanOffer offer,
  Iterable<PremiumPlanOffer> periods,
) {
  final monthly = periods
      .where(
        (period) =>
            period.months == 1 &&
            period.plan.devices == offer.plan.devices &&
            period.currencyCode == offer.currencyCode,
      )
      .firstOrNull;
  if (monthly == null || monthly.perMonthMicros <= 0) return null;

  final saved = monthly.perMonthMicros - offer.perMonthMicros;
  final percent = saved * 100 ~/ monthly.perMonthMicros;
  return percent > 0 ? percent : null;
}

/// The period among [periods] that costs least a month, when it saves
/// anything; null when none does, so no plan is called the best value for
/// costing the same.
PremiumPlanOffer? bestValue(Iterable<PremiumPlanOffer> periods) {
  PremiumPlanOffer? best;
  for (final period in periods) {
    if (savingsPercent(period, periods) == null) continue;
    if (best == null || period.perMonthMicros < best.perMonthMicros) {
      best = period;
    }
  }
  return best;
}

/// Offers grouped by device count, fewest devices first, each count's
/// periods shortest first: the order the bot has always listed them in.
SplayTreeMap<int, List<PremiumPlanOffer>> offersByDevices(
  Iterable<PremiumPlanOffer> offers,
) {
  final grouped = SplayTreeMap<int, List<PremiumPlanOffer>>();
  for (final offer in offers) {
    grouped.putIfAbsent(offer.plan.devices, () => []).add(offer);
  }
  for (final periods in grouped.values) {
    periods.sort((first, second) => first.months.compareTo(second.months));
  }
  return grouped;
}
