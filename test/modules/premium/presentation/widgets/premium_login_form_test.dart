import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_error_banner.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_login_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/coloured_shadows.dart';
import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

const _designSize = Size(393, 852);

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

/// Long enough for the toast to slide in.
const _toastSlideIn = Duration(milliseconds: 400);

Widget _formUnderTest(ProviderContainer container) {
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
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) => PremiumLoginForm(
                state: ref.watch(premiumProvider),
                accent: PremiumAccent.signedOut(
                  const PremiumPalette(AppPalette.dark),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Mounts the form against [repository] once the launch restore has found
  /// nobody signed in, and hands back the strings it is read in.
  Future<AppLocalizations> pumpForm(
    WidgetTester tester,
    FakePremiumRepository repository,
  ) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        premiumRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_formUnderTest(container));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(PremiumLoginForm)));
  }

  /// Presses sign in and lets whatever reports the answer slide in.
  Future<void> pressSignIn(WidgetTester tester, AppLocalizations l10n) async {
    // The switch above the form carries the same words.
    final button = find.widgetWithText(PremiumPrimaryButton, l10n.signIn);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    await tester.pump(_toastSlideIn);
  }

  /// [text] where the form draws it itself, rather than in the toast that is
  /// drawn above everything.
  Finder insideTheForm(String text) => find.descendant(
    of: find.byType(PremiumLoginForm),
    matching: find.text(text),
  );

  group('PremiumLoginForm', () {
    // The mono face is for readings: an address, a latency, a clock. The
    // eyebrow is a label, like the plan badge beside the app's name.
    testWidgets('should set the eyebrow in the body face, not the mono one', (
      tester,
    ) async {
      final l10n = await pumpForm(tester, FakePremiumRepository());

      final eyebrow = tester.widget<Text>(
        find.text(l10n.premiumHeroTitle.toUpperCase()),
      );

      expect(eyebrow.style?.fontFamily, isNot(AppFaces.mono));
    });

    // The label says what the button does; an arrow after it added nothing.
    testWidgets('should draw the sign-in button without an arrow', (
      tester,
    ) async {
      final l10n = await pumpForm(tester, FakePremiumRepository());

      expect(
        find.descendant(
          of: find.widgetWithText(PremiumPrimaryButton, l10n.signIn),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    // The crown tile is the brand's mark on the tab, not a state, so it
    // carries no glow.
    testWidgets('should draw its emblem without a glow', (tester) async {
      await pumpForm(tester, FakePremiumRepository());

      expect(
        colouredShadowsUnder(tester, find.byType(PremiumLoginForm)),
        isEmpty,
      );
    });

    testWidgets('should report a refused sign-in in the error toast', (
      tester,
    ) async {
      final l10n = await pumpForm(
        tester,
        FakePremiumRepository(
          signInResult: left(const RateLimitFailure('quota')),
        ),
      );
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      await tester.enterText(find.byType(TextField).at(0), 'user');
      await tester.enterText(find.byType(TextField).at(1), 'secret-password');
      await pressSignIn(tester, l10n);

      expect(find.text(error.message), findsOneWidget);
      expect(find.text(error.hint!), findsOneWidget);
      expect(
        insideTheForm(error.message),
        findsNothing,
        reason: 'the form used to print the reason in a banner above itself',
      );
      expect(find.byType(PremiumErrorBanner), findsNothing);

      await tester.pump(_pastTheToast);
    });

    // An empty sign-in is refused before anything is asked, with the same
    // state both times. A toast raised on a change of state would answer the
    // first press and stay silent for the second.
    testWidgets('should report an empty sign-in each time it is pressed', (
      tester,
    ) async {
      final l10n = await pumpForm(tester, FakePremiumRepository());
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.credentialsRequired,
        l10n,
      );

      await pressSignIn(tester, l10n);
      expect(find.text(error.message), findsOneWidget);

      await tester.pump(_pastTheToast);
      await tester.pumpAndSettle();
      expect(find.text(error.message), findsNothing);

      await pressSignIn(tester, l10n);
      expect(find.text(error.message), findsOneWidget);

      await tester.pump(_pastTheToast);
    });
  });
}
