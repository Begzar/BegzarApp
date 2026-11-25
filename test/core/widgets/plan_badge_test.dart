import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/widgets/plan_badge.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);

/// The badge alone, in [locale] and the face the app sets it in, on the plan
/// [isPremium] names.
Future<void> _pumpBadge(
  WidgetTester tester, {
  required bool isPremium,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        locale: locale,
        theme: ThemeData(fontFamily: appFontFamilyFor(locale)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fa')],
        home: Scaffold(
          body: Center(child: PlanBadge(isPremium: isPremium)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
        as BoxDecoration;

Text _label(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(PlanBadge), matching: find.byType(Text)),
);

void main() {
  group('PlanBadge', () {
    // A filled blue tag beside the name was the loudest thing at the top of
    // the home screen, louder than the dial it sits above. Outlined, it still
    // says Premium in the accent without competing with the way in.
    testWidgets('should outline premium in the accent instead of filling it', (
      tester,
    ) async {
      await _pumpBadge(tester, isPremium: true);
      final decoration = _decoration(tester);
      final rim = (decoration.border! as Border).top.color;

      expect(decoration.gradient, isNull);
      expect(rim.a, greaterThan(0));
      expect(rim, isNot(isSameColorAs(Colors.transparent)));
      expect(
        _label(tester).style?.color,
        isSameColorAs(AppPalette.dark.accent),
      );
    });

    // The mono face is for readings: an address, a latency, a clock. A plan
    // name is a word, and the tag stops borrowing the readings' face.
    testWidgets('should set the label in the body face, not the mono one', (
      tester,
    ) async {
      await _pumpBadge(tester, isPremium: true);

      expect(_label(tester).style?.fontFamily, isNot(AppFaces.mono));
    });

    // `پایه` carries more of its weight high than `پریمیوم`, so on one
    // baseline, the one Premium reads as centred on, Basic sat high.
    testWidgets('should set Persian Basic lower than Premium, by the weight '
        'of its ink', (tester) async {
      await _pumpBadge(tester, isPremium: false, locale: const Locale('fa'));
      final basic = _baseline(tester);
      await _pumpBadge(tester, isPremium: true, locale: const Locale('fa'));
      final premium = _baseline(tester);

      expect(
        basic - premium,
        moreOrLessEquals(AppLayout.planBadgeFont.sp * (0.205 - 0.125)),
      );
    });

    // Latin plan names are set in capitals, which share one band of ink.
    testWidgets('should set both English plans on one baseline', (
      tester,
    ) async {
      await _pumpBadge(tester, isPremium: false);
      final basic = _baseline(tester);
      await _pumpBadge(tester, isPremium: true);

      expect(_baseline(tester), basic);
    });
  });
}

double _baseline(WidgetTester tester) => tester
    .widget<Baseline>(
      find.descendant(
        of: find.byType(PlanBadge),
        matching: find.byType(Baseline),
      ),
    )
    .baseline;
