import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coloured_shadows.dart';

const _designSize = Size(393, 852);
const _label = 'Save';

/// A popup's action button alone, enabled when [onPressed] is set.
Future<void> _pumpButton(WidgetTester tester, {VoidCallback? onPressed}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: InkFilledButton(
              label: _label,
              color: AppPalette.dark.accent,
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
                    of: find.byType(InkFilledButton),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('InkDialogEmblem', () {
    // The tile is washed and rimmed in the popup's colour; a light spilling
    // round it was one more glow on a screen that should have none.
    testWidgets('should draw the emblem without a glow', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: _designSize,
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: InkDialogEmblem(
                  icon: Icons.public,
                  color: AppPalette.dark.premiumInk,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        colouredShadowsUnder(tester, find.byType(InkDialogEmblem)),
        isEmpty,
      );
    });
  });

  group('InkFilledButton', () {
    // A glow on this app marks a state, like the dial's connection; an action
    // is a solid fill, so a popup's Save reads the way every other primary
    // button does.
    testWidgets('should draw no glow while enabled', (tester) async {
      await _pumpButton(tester, onPressed: () {});

      expect(_fill(tester).boxShadow ?? const <BoxShadow>[], isEmpty);
    });

    // With the glow gone, the dimmed fill is what says the action waits.
    testWidgets('should dim while disabled', (tester) async {
      await _pumpButton(tester);

      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(InkFilledButton),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        lessThan(1),
      );
    });
  });
}
