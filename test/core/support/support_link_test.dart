import 'package:begzar/core/support/support_link.dart';
import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _hosting(Widget child, {Locale locale = const Locale('en')}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fa')],
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The label's colour, read off the widget tree rather than off the palette,
/// so the assertion fails if the link is ever repainted at the call site.
Color _labelColour(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!.color!;

void main() {
  group('the support link says where it goes', () {
    testWidgets('it carries the mark beside the label', (tester) async {
      await tester.pumpWidget(_hosting(const SupportLink(message: 'help me')));

      expect(find.byType(TelegramMark), findsOneWidget);
      expect(find.text('Get help'), findsOneWidget);
    });

    testWidgets('the label is translated', (tester) async {
      await tester.pumpWidget(
        _hosting(
          const SupportLink(message: 'help me'),
          locale: const Locale('fa'),
        ),
      );

      expect(find.text('دریافت راهنمایی'), findsOneWidget);
    });

    testWidgets('the mark takes the label\'s colour', (tester) async {
      await tester.pumpWidget(_hosting(const SupportLink(message: 'help me')));

      expect(
        tester.widget<TelegramMark>(find.byType(TelegramMark)).color,
        _labelColour(tester),
      );
    });
  });

  group('the exit is not painted as the failure', () {
    // The four screens that show this each used their own red — three shades
    // between them — which made the one control that undoes an error look
    // like part of it. Anything red here is a regression, whichever red.
    testWidgets('the link is white, not an error colour', (tester) async {
      await tester.pumpWidget(_hosting(const SupportLink(message: 'help me')));

      final colour = _labelColour(tester);
      expect(colour.r, colour.g);
      expect(colour.g, colour.b);
    });
  });

  group('a deferred link leaves the opening to its host', () {
    // The error toast has to take itself off screen before the chat opens, and
    // by then its own context is gone.
    testWidgets('tapping runs the host\'s callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hosting(SupportLink.deferred(onTap: () => taps++)),
      );

      await tester.tap(find.byType(SupportLink));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('it looks the same as the one that opens directly', (
      tester,
    ) async {
      await tester.pumpWidget(_hosting(const SupportLink(message: 'help me')));
      final direct = _labelColour(tester);
      final directMark = tester.widget<TelegramMark>(
        find.byType(TelegramMark),
      );

      await tester.pumpWidget(_hosting(SupportLink.deferred(onTap: () {})));

      expect(_labelColour(tester), direct);
      expect(
        tester.widget<TelegramMark>(find.byType(TelegramMark)).size,
        directMark.size,
      );
    });
  });
}
