import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_sign_up_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

const _designSize = Size(393, 852);

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

/// Long enough for the toast to slide in.
const _toastSlideIn = Duration(milliseconds: 400);

/// A password the form accepts, so the server is what refuses.
const _password = 'correct horse battery';

Widget _sectionUnderTest(ProviderContainer container) {
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
            child: PremiumSignUpSection(
              accent: PremiumAccent.signedOut(
                const PremiumPalette(AppPalette.dark),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Mounts the details step against [repository] and hands back the strings
  /// it is read in.
  Future<AppLocalizations> pumpSection(
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

    await tester.pumpWidget(_sectionUnderTest(container));
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(PremiumSignUpSection)),
    );
  }

  /// Fills the details in, presses create, and lets whatever reports the
  /// answer slide in.
  Future<void> createAccount(WidgetTester tester, AppLocalizations l10n) async {
    await tester.enterText(find.byType(TextField).at(0), 'reader@example.com');
    await tester.enterText(find.byType(TextField).at(1), _password);
    await tester.enterText(find.byType(TextField).at(2), _password);

    final button = find.text(l10n.createAccount);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    await tester.pump(_toastSlideIn);
  }

  group('PremiumSignUpSection', () {
    // The label says what the button does; an arrow after it added nothing.
    testWidgets('should draw the create-account button without an arrow', (
      tester,
    ) async {
      final l10n = await pumpSection(tester, FakePremiumRepository());

      expect(
        find.descendant(
          of: find.widgetWithText(PremiumPrimaryButton, l10n.createAccount),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    // Flush with the field's outer edge, the flat bars ran past its rounded
    // corners and read as wider than the field above them.
    testWidgets('should keep the strength meter inside the field\'s padding', (
      tester,
    ) async {
      await pumpSection(tester, FakePremiumRepository());

      final bars = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.constraints?.maxHeight == AppLayout.premiumMeterHeight,
      );
      final field = tester.getRect(find.byType(TextField).at(1));
      expect(bars, findsNWidgets(4));
      expect(
        tester.getRect(bars.first).left,
        closeTo(field.left + AppLayout.premiumFieldPadStart, 0.5),
      );
      expect(
        tester.getRect(bars.last).right,
        closeTo(field.right - AppLayout.premiumFieldPadStart, 0.5),
      );
    });

    testWidgets('should report a refused sign-up in the error toast', (
      tester,
    ) async {
      final l10n = await pumpSection(
        tester,
        FakePremiumRepository(
          signUpResult: left(const RateLimitFailure('quota')),
        ),
      );
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      await createAccount(tester, l10n);

      expect(find.text(error.message), findsOneWidget);
      expect(find.text(error.hint!), findsOneWidget);

      await tester.pump(_pastTheToast);
    });

    // The same refusal twice is still two answers. Each try clears the last
    // one first, which is what lets the second be reported at all.
    testWidgets('should report the same refusal again on the next try', (
      tester,
    ) async {
      final l10n = await pumpSection(
        tester,
        FakePremiumRepository(
          signUpResult: left(const RateLimitFailure('quota')),
        ),
      );
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      await createAccount(tester, l10n);
      await tester.pump(_pastTheToast);
      await tester.pumpAndSettle();
      expect(find.text(error.message), findsNothing);

      await createAccount(tester, l10n);
      expect(find.text(error.message), findsOneWidget);

      await tester.pump(_pastTheToast);
    });
  });
}
