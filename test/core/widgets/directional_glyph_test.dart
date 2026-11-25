import 'package:begzar/core/widgets/directional_glyph.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Resolves both glyphs under one text direction, from a real element so
  /// the lookup goes through [Directionality] the way a widget's does.
  Future<({IconData chevron, IconData back})> glyphsIn(
    WidgetTester tester,
    TextDirection direction,
  ) async {
    late IconData chevron;
    late IconData back;

    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) {
            chevron = DirectionalGlyph.chevron(context);
            back = DirectionalGlyph.back(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    return (chevron: chevron, back: back);
  }

  group('DirectionalGlyph', () {
    // Material declared these two with matchTextDirection and turned them
    // round on its own. Iconsax does not, so the flip is now this file's job —
    // and Persian is the language most of this app's readers use, which makes
    // a chevron pointing into the text it closes the failure that matters.
    testWidgets('should point the chevron the way the reader travels', (
      tester,
    ) async {
      final ltr = await glyphsIn(tester, TextDirection.ltr);
      final rtl = await glyphsIn(tester, TextDirection.rtl);

      expect(
        rtl.chevron,
        isNot(ltr.chevron),
        reason:
            'a row-opening chevron that did not flip would point back '
            'into the title it closes',
      );
    });

    testWidgets('should point back against the way the reader travels', (
      tester,
    ) async {
      final ltr = await glyphsIn(tester, TextDirection.ltr);
      final rtl = await glyphsIn(tester, TextDirection.rtl);

      expect(rtl.back, isNot(ltr.back));
    });

    // The two are opposite senses of one arrow, which is the whole reason they
    // are a pair rather than one helper used twice. Getting them to agree
    // would draw a back button that points further into the app.
    testWidgets('should draw back and chevron opposite each other', (
      tester,
    ) async {
      final ltr = await glyphsIn(tester, TextDirection.ltr);
      expect(ltr.back, isNot(ltr.chevron));

      final rtl = await glyphsIn(tester, TextDirection.rtl);
      expect(rtl.back, isNot(rtl.chevron));
    });

    testWidgets('should swap the pair between the two directions', (
      tester,
    ) async {
      final ltr = await glyphsIn(tester, TextDirection.ltr);
      final rtl = await glyphsIn(tester, TextDirection.rtl);

      expect(rtl.chevron, ltr.back);
      expect(rtl.back, ltr.chevron);
    });
  });
}
