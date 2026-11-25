import 'dart:async';

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_error_banner.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

const _designSize = Size(393, 852);
const _openLabel = 'open';
const _microsPerCent = 10000;

/// Longer than the page route takes to slide in, for a page that never
/// settles because its spinner keeps turning.
const _routeTransition = Duration(seconds: 1);

/// How far, in logical pixels, a laid-out edge may sit from where it is
/// expected: the layout rounds, the page does not move by a pixel on purpose.
const _layoutTolerance = 1.0;

PremiumPlanOffer _offer(int devices, int months, int cents) => PremiumPlanOffer(
  plan: PremiumPlan(
    devices: devices,
    productId: 'premium_${devices}_device',
    basePlanId: 'premium-$devices-device-$months',
  ),
  price: '\$${(cents / 100).toStringAsFixed(2)}',
  months: months,
  priceMicros: cents * _microsPerCent,
  currencyCode: 'USD',
);

/// Two dollars a device a month, a little less a month for longer, for one,
/// three and five devices; nothing is sold for two or four.
final _offers = [
  _offer(1, 1, 200),
  _offer(1, 3, 570),
  _offer(1, 12, 1920),
  _offer(3, 1, 600),
  _offer(3, 3, 1710),
  _offer(3, 12, 5760),
  _offer(5, 1, 1000),
  _offer(5, 12, 9600),
];

Widget _appOpeningThePaywall(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPremiumPaywall(context),
              child: const Text(_openLabel),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens the paywall over [offers], [_offers] unless given, and hands back the
/// strings it is read in.
///
/// With [holdOffers] the offers do not arrive until the test completes it, so
/// the page stays on its spinner; that never settles, so the route's slide-in
/// is pumped through instead.
Future<AppLocalizations> _openPaywall(
  WidgetTester tester, {
  List<PremiumPlanOffer>? offers,
  Completer<void>? holdOffers,
}) async {
  tester.view.physicalSize = _designSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      premiumRepositoryProvider.overrideWithValue(FakePremiumRepository()),
      googlePlayBillingRepositoryProvider.overrideWithValue(
        FakeGooglePlayBillingRepository(offersResult: right(offers ?? _offers))
          ..holdOffers = holdOffers,
      ),
      analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(_appOpeningThePaywall(container));
  await tester.tap(find.text(_openLabel));
  if (holdOffers == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(_routeTransition);
  }
  // The page covers the button that opened it, so it is looked for off stage.
  return AppLocalizations.of(
    tester.element(find.text(_openLabel, skipOffstage: false)),
  );
}

IconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

/// Where one of the page's private parts is laid out, found by its type's
/// name since the type itself cannot be named from here.
Rect _rectOf(WidgetTester tester, String typeName) => tester.getRect(
  find.byWidgetPredicate((widget) => widget.runtimeType.toString() == typeName),
);

/// Scrolls [target] out from under the pinned bar, as a reader would, and taps
/// it.
Future<void> _tapInView(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('showPremiumPaywall', () {
    testWidgets("should name the best value's price on the button", (
      tester,
    ) async {
      final l10n = await _openPaywall(tester);

      expect(
        find.text(l10n.paywallContinue('year', r'$57.60', 12)),
        findsOneWidget,
      );
    });

    testWidgets('should say what each longer period saves', (tester) async {
      final l10n = await _openPaywall(tester);

      expect(find.text(l10n.paywallSave(5)), findsOneWidget);
      expect(find.text(l10n.paywallSave(20)), findsOneWidget);
    });

    testWidgets('should mark only the best value', (tester) async {
      final l10n = await _openPaywall(tester);

      expect(find.text(l10n.paywallBestValue), findsOneWidget);
    });

    testWidgets('should name another period on the button once picked', (
      tester,
    ) async {
      final l10n = await _openPaywall(tester);

      await _tapInView(tester, find.text(l10n.paywallMonths(3)));

      expect(
        find.text(l10n.paywallContinue('other', r'$17.10', 3)),
        findsOneWidget,
      );
    });

    testWidgets('should step down to the fewest devices sold and stop', (
      tester,
    ) async {
      final l10n = await _openPaywall(tester);

      await _tapInView(tester, find.byTooltip(l10n.paywallFewerDevices));

      expect(find.text(l10n.paywallDevices(1)), findsOneWidget);
      expect(_button(tester, l10n.paywallFewerDevices).onPressed, isNull);
      expect(_button(tester, l10n.paywallMoreDevices).onPressed, isNotNull);
    });

    testWidgets('should step over a device count Play does not sell', (
      tester,
    ) async {
      final l10n = await _openPaywall(tester);

      await _tapInView(tester, find.byTooltip(l10n.paywallMoreDevices));

      expect(find.text(l10n.paywallDevices(5)), findsOneWidget);
      expect(_button(tester, l10n.paywallMoreDevices).onPressed, isNull);
    });

    // The spinner stands in for the plan card, so it sits in the middle of
    // the space the card will take, between the table and the pay bar.
    testWidgets('should centre the spinner between the table and the pay bar '
        'while Play prices the plans', (tester) async {
      await _openPaywall(tester, holdOffers: Completer<void>());

      final table = _rectOf(tester, '_Comparison');
      final payBar = _rectOf(tester, '_PayBar');
      final spinner = tester.getRect(find.byType(CircularProgressIndicator));

      expect(
        spinner.center.dy,
        moreOrLessEquals(
          (table.bottom + payBar.top) / 2,
          epsilon: _layoutTolerance,
        ),
      );
    });

    // With nothing to sell, the banner saying so takes the plan card's place
    // the way the spinner did.
    testWidgets('should centre the plans-unavailable banner between the table '
        'and the pay bar', (tester) async {
      await _openPaywall(tester, offers: const []);

      final table = _rectOf(tester, '_Comparison');
      final payBar = _rectOf(tester, '_PayBar');
      final banner = tester.getRect(find.byType(PremiumErrorBanner));

      expect(
        banner.center.dy,
        moreOrLessEquals(
          (table.bottom + payBar.top) / 2,
          epsilon: _layoutTolerance,
        ),
      );
    });

    // Yellow means a warning or something in progress everywhere else in the
    // app; the Basic column takes the muted ink its badge is drawn in.
    testWidgets("should draw the Basic heading in the badge's muted ink", (
      tester,
    ) async {
      final l10n = await _openPaywall(tester);

      expect(
        tester.widget<Text>(find.text(l10n.planBasic)).style?.color,
        isSameColorAs(AppPalette.dark.planBasicInk),
      );
    });

    // Centred in the space is not filling it: the banner keeps as much room
    // under its last line as over its first, however tall the space it is in.
    testWidgets('should wrap the plans-unavailable banner around its lines', (
      tester,
    ) async {
      await _openPaywall(tester, offers: const []);

      final banner = find.byType(PremiumErrorBanner);
      final lines = find.descendant(of: banner, matching: find.byType(Text));
      final bannerRect = tester.getRect(banner);
      final firstLine = tester.getRect(lines.first);
      final lastLine = tester.getRect(lines.last);

      expect(
        bannerRect.bottom - lastLine.bottom,
        moreOrLessEquals(
          firstLine.top - bannerRect.top,
          epsilon: _layoutTolerance,
        ),
      );
    });

    // The design size is the view's own, so a gap in the layout tokens is the
    // same number of logical pixels on screen.
    testWidgets('should keep the plan card right under the table', (
      tester,
    ) async {
      await _openPaywall(tester);

      final table = _rectOf(tester, '_Comparison');
      final card = _rectOf(tester, '_PlanCard');

      expect(
        card.top - table.bottom,
        moreOrLessEquals(
          AppLayout.premiumPaywallSectionGap,
          epsilon: _layoutTolerance,
        ),
      );
    });
  });
}
