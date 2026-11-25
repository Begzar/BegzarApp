import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/core/widgets/plan_badge.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/home_app_bar.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wider than the 393 the bar is designed for, because the font the test
/// binding substitutes draws every glyph as a fixed-width box and makes the
/// Latin wordmark roughly twice the width any real font gives it. Every
/// assertion here compares one rect against another rather than against a
/// number, so the extra room costs nothing and the bar is measured instead of
/// being measured against an overflow.
const _surface = Size(640, 852);

/// What the bar is laid out for, which is what ScreenUtil scales against.
const _designSize = Size(393, 852);

/// The name the bar sets, per locale. Spelled out here rather than read back
/// from the localizations under test, so a name that silently stopped being
/// translated would fail rather than agree with itself.
const _names = {'en': 'BEGZAR', 'fa': 'بگذر'};

/// Reports a fixed status without watching the service graph.
class _FixedConnection extends ConnectionNotifier {
  _FixedConnection(this.status);

  final ConnectionStatus status;

  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: status);
}

/// Signed out, which is the state that needs no services behind it.
class _FixedPremium extends PremiumNotifier {
  @override
  PremiumState build() => const PremiumSignedOut();
}

void main() {
  /// Mounts the bar in one reading direction.
  Future<void> pumpBar(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = _surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(
            () => _FixedConnection(ConnectionStatus.ready),
          ),
          premiumProvider.overrideWith(_FixedPremium.new),
        ],
        child: ScreenUtilInit(
          designSize: _designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => MaterialApp(
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fa')],
            home: const Scaffold(body: HomeAppBar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The two rects the layout is judged on, in the locale just pumped.
  (Rect name, Rect controls) boxesFor(WidgetTester tester, Locale locale) {
    return (
      tester.getRect(find.text(_names[locale.languageCode]!)),
      tester.getRect(find.byType(TelegramMark)),
    );
  }

  group('the bar follows the reading direction', () {
    // It used to be pinned left-to-right in every locale on the grounds that a
    // brand lockup belongs on the same side everywhere. The name and the
    // controls are a title row, though, and a title row that stays put while
    // everything under it turns around reads as a bar from another app.
    testWidgets('English keeps the name ahead of the controls', (tester) async {
      const locale = Locale('en');
      await pumpBar(tester, locale);
      final (name, controls) = boxesFor(tester, locale);

      expect(name.center.dx, lessThan(controls.center.dx));
    });

    testWidgets('Persian moves the name to the other side', (tester) async {
      const locale = Locale('fa');
      await pumpBar(tester, locale);
      final (name, controls) = boxesFor(tester, locale);

      expect(name.center.dx, greaterThan(controls.center.dx));
    });
  });

  group('the name is the one the locale uses', () {
    // The app answers to a different name in Persian, so the wordmark is a
    // translated string rather than a fixed piece of Latin art.
    for (final entry in _names.entries) {
      testWidgets('${entry.key}: the bar reads "${entry.value}"', (
        tester,
      ) async {
        await pumpBar(tester, Locale(entry.key));

        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });

  group('the plan beside the name is translated', () {
    // The badge used to draw 'Premium'/'Basic' as fixed Latin on the grounds
    // that those are the plan names the site bills under. A plan is a thing
    // the user is on, though, not what the app is called, and it sat in Latin
    // beside a Persian name in a Persian bar.
    // Latin is set in capitals, as a tag; Persian, which has none, as is.
    for (final entry in const {'en': 'BASIC', 'fa': 'پایه'}.entries) {
      testWidgets('${entry.key}: signed out reads "${entry.value}"', (
        tester,
      ) async {
        await pumpBar(tester, Locale(entry.key));

        expect(find.text(entry.value), findsOneWidget);
      });
    }
  });

  group('the plan badge is the same pill in every language', () {
    // Its height used to come from whatever line box the locale's font handed
    // it, so the badge changed size between languages and the label sat low in
    // Persian. It is a fixed pill now, with the label placed by its baseline.
    testWidgets('English and Persian draw it the same size', (tester) async {
      await pumpBar(tester, const Locale('en'));
      final english = tester.getSize(find.byType(PlanBadge));

      await pumpBar(tester, const Locale('fa'));
      final persian = tester.getSize(find.byType(PlanBadge));

      expect(persian.height, english.height);
    });
  });

  // A paper plane alone did not say what it opened: the channel is where
  // support is asked for, so the button says so.
  group('HomeAppBar channel button', () {
    testWidgets('should label the channel button as support', (tester) async {
      await pumpBar(tester, const Locale('en'));
      final l10n = AppLocalizations.of(tester.element(find.byType(HomeAppBar)));

      expect(find.text(l10n.homeSupport), findsOneWidget);
    });
  });

  group('the name stands without a mark', () {
    // The bird used to open the lockup, turned over in Persian to face the
    // name. The bar carries the name alone now, and the dial is the one place
    // on the home screen that draws the mark.
    for (final languageCode in _names.keys) {
      testWidgets('$languageCode: the bar draws no image', (tester) async {
        await pumpBar(tester, Locale(languageCode));

        expect(find.byType(Image), findsNothing);
      });
    }

    // The channel button is the tallest thing in the row, so taking the mark
    // out must not move anything the screen lays out under the bar.
    testWidgets('the bar keeps the height the channel button gives it', (
      tester,
    ) async {
      await pumpBar(tester, const Locale('en'));

      expect(
        tester.getSize(find.byType(HomeAppBar)).height,
        AppLayout.mainAppBarTopInset.h + MainPalette.appBarTapTarget.w,
      );
    });
  });
}
