import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/presentation/widgets/routing_rules_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);

Finder _ruleTileOf(String value) => find.byWidgetPredicate(
  (widget) => widget is RoutingRuleTile && widget.value == value,
);

void main() {
  group('RoutingRulesTab', () {
    // The tabs' nav bar floats over every screen pushed inside a tab, so a
    // list that ends at the screen's edge leaves its last rule under the bar.
    testWidgets('should end the list above the floating nav bar', (
      tester,
    ) async {
      tester.view.physicalSize = _designSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final domains = [
        for (var index = 0; index < 20; index++) 'domain:site$index.example',
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: _designSize,
            builder: (context, _) => MaterialApp(
              home: Scaffold(
                body: RoutingRulesTab(
                  action: RoutingAction.direct,
                  rules: CustomRoutingRules(directDomains: domains),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final navBarTop = _designSize.height - NavBar.footprint;
      expect(
        tester.getRect(_ruleTileOf(domains.last)).bottom,
        lessThan(navBarTop),
      );
    });
  });
}
