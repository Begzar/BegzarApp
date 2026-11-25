import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/app_update/presentation/widgets/update_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _label = 'Update available';

Future<void> _pumpDot(WidgetTester tester, {String? semanticLabel}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (context, _) => MaterialApp(
        home: Center(child: UpdateDot(semanticLabel: semanticLabel)),
      ),
    ),
  );
}

void main() {
  group('UpdateDot', () {
    // The switches' yellow, so the news reads in the app's own accent rather
    // than in the destructive red an error would use.
    testWidgets('should paint the dot in the yellow the switches use', (
      tester,
    ) async {
      await _pumpDot(tester);

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(UpdateDot),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, AppPalette.dark.warning);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('should announce itself when given a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDot(tester, semanticLabel: _label);

      expect(find.bySemanticsLabel(_label), findsOneWidget);
      semantics.dispose();
    });

    // On a row whose title already says "Update available", a label on the
    // dot would only say it twice.
    testWidgets('should stay silent without a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDot(tester);

      expect(find.bySemanticsLabel(_label), findsNothing);
      semantics.dispose();
    });
  });
}
