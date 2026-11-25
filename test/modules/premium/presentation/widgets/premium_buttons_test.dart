import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);
const _label = 'Sign in';

/// The account tab's primary button alone, enabled when [onPressed] is set.
Future<void> _pumpButton(WidgetTester tester, {VoidCallback? onPressed}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumPrimaryButton(
              label: _label,
              accent: PremiumAccent.signedOut(
                const PremiumPalette(AppPalette.dark),
              ),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The decoration the button's fill is drawn with.
BoxDecoration _fill(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(PremiumPrimaryButton),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('PremiumPrimaryButton', () {
    // Only the dial glows on this app, and its glow says what the connection
    // is doing. A button glowing at rest borrowed that language, and the
    // app's other primary button never glowed.
    testWidgets('should draw no glow while enabled', (tester) async {
      await _pumpButton(tester, onPressed: () {});

      expect(_fill(tester).boxShadow ?? const <BoxShadow>[], isEmpty);
    });

    // With the glow gone, the dimmed fill is what says a sign-in is waiting.
    testWidgets('should dim while disabled', (tester) async {
      await _pumpButton(tester);

      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(PremiumPrimaryButton),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        PremiumPalette.disabledAlpha,
      );
    });
  });
}
