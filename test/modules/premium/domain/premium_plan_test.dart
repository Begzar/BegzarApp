import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _dollar = 1000000;

PremiumPlanOffer _offer(
  int devices,
  int months, {
  int priceMicros = _dollar,
  String currencyCode = 'USD',
}) => PremiumPlanOffer(
  plan: PremiumPlan(
    devices: devices,
    productId: 'premium_$devices',
    basePlanId: 'p$months',
  ),
  price: '\$$months.99',
  months: months,
  priceMicros: priceMicros,
  currencyCode: currencyCode,
);

/// One device at two dollars a month, a little less a month for longer.
final _periods = [
  _offer(1, 1, priceMicros: 2 * _dollar),
  _offer(1, 3, priceMicros: 5700000),
  _offer(1, 6, priceMicros: 10800000),
  _offer(1, 12, priceMicros: 19200000),
];

void main() {
  group('billingPeriodMonths', () {
    test('should read P1M, P3M, P6M and P1Y as 1, 3, 6 and 12 months', () {
      expect(billingPeriodMonths('P1M'), 1);
      expect(billingPeriodMonths('P3M'), 3);
      expect(billingPeriodMonths('P6M'), 6);
      expect(billingPeriodMonths('P1Y'), 12);
    });

    test('should refuse a weekly period', () {
      expect(billingPeriodMonths('P1W'), isNull);
      expect(billingPeriodMonths('P4W'), isNull);
    });
  });

  group('offersByDevices', () {
    test('should group offers by device count in order', () {
      final grouped = offersByDevices([
        _offer(3, 1),
        _offer(1, 1),
        _offer(2, 1),
      ]);

      expect(grouped.keys, [1, 2, 3]);
    });

    test("should order each device count's periods", () {
      final grouped = offersByDevices([
        _offer(1, 12),
        _offer(1, 1),
        _offer(1, 6),
        _offer(1, 3),
      ]);

      expect(grouped[1]!.map((offer) => offer.months), [1, 3, 6, 12]);
    });
  });

  group('PremiumPlanOffer.perMonthMicros', () {
    test('should divide the price by the months it buys', () {
      expect(_periods.last.perMonthMicros, 1600000);
    });
  });

  group('savingsPercent', () {
    test("should compare a period with the same count's monthly plan", () {
      expect(savingsPercent(_periods[1], _periods), 5);
      expect(savingsPercent(_periods[2], _periods), 10);
      expect(savingsPercent(_periods[3], _periods), 20);
    });

    test('should round a saving down rather than claim more', () {
      final periods = [
        _offer(1, 1, priceMicros: 3 * _dollar),
        _offer(1, 3, priceMicros: 8600000),
      ];

      expect(savingsPercent(periods[1], periods), 4);
    });

    test('should claim no saving for the monthly plan itself', () {
      expect(savingsPercent(_periods.first, _periods), isNull);
    });

    test('should claim no saving without a monthly plan to compare', () {
      final periods = _periods.skip(1).toList();

      expect(savingsPercent(periods.last, periods), isNull);
    });

    test('should claim no saving across currencies', () {
      final periods = [
        _offer(1, 1, priceMicros: 2 * _dollar),
        _offer(1, 12, priceMicros: 19200000, currencyCode: 'EUR'),
      ];

      expect(savingsPercent(periods[1], periods), isNull);
    });

    test('should claim no saving for a period dearer by the month', () {
      final periods = [
        _offer(1, 1, priceMicros: 2 * _dollar),
        _offer(1, 3, priceMicros: 6600000),
      ];

      expect(savingsPercent(periods[1], periods), isNull);
    });
  });

  group('bestValue', () {
    test('should pick the period with the lowest price per month', () {
      expect(bestValue(_periods), _periods.last);
    });

    test('should pick none when no period saves', () {
      final periods = [
        _offer(1, 1, priceMicros: 2 * _dollar),
        _offer(1, 3, priceMicros: 6 * _dollar),
      ];

      expect(bestValue(periods), isNull);
    });
  });
}
