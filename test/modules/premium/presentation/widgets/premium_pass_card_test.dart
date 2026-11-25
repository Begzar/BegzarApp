import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_pass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/coloured_shadows.dart';

const _designSize = Size(393, 852);
const _plan = 'Premium';
const _tier = 'Basic';
const _username = 'someone';
const _status = 'Active';

/// A pass in English: by default for an account that has never paid, with the
/// plan in the corner, the tier tag opposite it, and no sheen sweeping over
/// it, so the card is at rest after its first frame.
Future<void> _pumpCard(
  WidgetTester tester, {
  PremiumPassTone tone = PremiumPassTone.open,
  String? statusLabel,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: PremiumPassCard(
            tone: tone,
            planLabel: _plan,
            username: _username,
            statusLabel: statusLabel,
            tierLabel: statusLabel == null ? _tier : null,
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String? _familyOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.fontFamily;

void main() {
  group('PremiumPassCard', () {
    // The mono face is for readings. A plan name and a tier are words, set
    // in the body face like the plan badge in the app bar.
    testWidgets('should set the plan label in the body face', (tester) async {
      await _pumpCard(tester);

      expect(_familyOf(tester, _plan.toUpperCase()), isNot(AppFaces.mono));
    });

    testWidgets('should set the tier tag in the body face', (tester) async {
      await _pumpCard(tester);

      expect(_familyOf(tester, _tier.toUpperCase()), isNot(AppFaces.mono));
    });

    // A live pass is told by its blue face and its status chip; a glow under
    // the card and a ring breathing out of the dot were halos on top.
    testWidgets('should draw a live pass without a glow', (tester) async {
      await _pumpCard(
        tester,
        tone: PremiumPassTone.entitled,
        statusLabel: _status,
      );

      expect(
        colouredShadowsUnder(tester, find.byType(PremiumPassCard)),
        isEmpty,
      );

      // Takes the card down, so the timers a live pass starts are cancelled.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // A username is a reading, so it keeps the mono face the labels lost.
    testWidgets('should keep the username in the mono face', (tester) async {
      await _pumpCard(tester);

      expect(_familyOf(tester, _username), AppFaces.mono);
    });

    // The live pass is a card of its own colour on either page: navy on a
    // dark one, the accent's blue on a light one, where navy was the darkest
    // thing in the theme. Either way its ink is the one its card takes, not
    // the page's.
    testWidgets('should draw a live pass in the day pass\'s ink on a light '
        'page', (tester) async {
      await _pumpCard(
        tester,
        tone: PremiumPassTone.entitled,
        statusLabel: _status,
        theme: AppTheme.light(fontFamily: 'Roboto'),
      );

      expect(
        tester.widget<Text>(find.text(_username)).style?.color,
        PremiumPalette.passDayInk.text,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('should draw a live pass in the dark ink on a dark page', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        tone: PremiumPassTone.entitled,
        statusLabel: _status,
        theme: AppTheme.dark(fontFamily: 'Roboto'),
      );

      expect(
        tester.widget<Text>(find.text(_username)).style?.color,
        AppPalette.dark.text,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('should draw an open pass in the page ink on a light page', (
      tester,
    ) async {
      await _pumpCard(tester, theme: AppTheme.light(fontFamily: 'Roboto'));

      expect(
        tester.widget<Text>(find.text(_username)).style?.color,
        AppPalette.light.text,
      );
    });
  });
}
