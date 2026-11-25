import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_account_panel.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_device_row.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

const _designSize = Size(393, 852);

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

/// Long enough for the toast to slide in.
const _toastSlideIn = Duration(milliseconds: 400);

PremiumSession _signedIn() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);

Widget _panelUnderTest(ProviderContainer container) {
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
              builder: (context, ref, _) {
                final state = ref.watch(premiumProvider);
                // The account screen shows the panel to a signed-in account
                // only, and so does this.
                if (!state.isLoggedIn) return const SizedBox.shrink();
                return PremiumAccountPanel(
                  state: state,
                  accent: PremiumAccent.entitled(
                    const PremiumPalette(AppPalette.dark),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Mounts the panel for a restored session and hands back the strings it is
  /// read in.
  Future<AppLocalizations> pumpPanel(
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

    await tester.pumpWidget(_panelUnderTest(container));
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(PremiumAccountPanel)),
    );
  }

  /// Presses the button labelled [label] and lets whatever reports the answer
  /// slide in.
  Future<void> press(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    await tester.pump(_toastSlideIn);
  }

  /// [text] where the panel draws it itself, rather than in the toast that is
  /// drawn above everything.
  Finder insideThePanel(String text) => find.descendant(
    of: find.byType(PremiumAccountPanel),
    matching: find.text(text),
  );

  group('PremiumAccountPanel', () {
    testWidgets('should report a failed refresh in the error toast', (
      tester,
    ) async {
      final repository = FakePremiumRepository(session: _signedIn());
      final l10n = await pumpPanel(tester, repository);
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      repository.refreshResult = left(const RateLimitFailure('quota'));
      await press(tester, l10n.refresh);

      expect(find.text(error.message), findsOneWidget);
      expect(
        insideThePanel(error.message),
        findsNothing,
        reason: 'the panel used to print the reason in a banner of its own',
      );
      expect(find.byType(PremiumErrorBanner), findsNothing);

      await tester.pump(_pastTheToast);
    });

    testWidgets('should report a failed sign-out in the error toast', (
      tester,
    ) async {
      final repository = FakePremiumRepository(session: _signedIn());
      final l10n = await pumpPanel(tester, repository);
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.signOutFailed,
        l10n,
      );

      repository.signOutError = StateError('storage will not answer');
      await press(tester, l10n.signOut);

      expect(find.text(error.message), findsOneWidget);
      expect(insideThePanel(error.message), findsNothing);
      expect(find.byType(PremiumErrorBanner), findsNothing);

      await tester.pump(_pastTheToast);
    });

    // Flush with the cards' outer edge, the seat meter and the count ran past
    // their rounded corners and read as wider than the cards under them.
    testWidgets('should keep the devices header inside the cards\' padding', (
      tester,
    ) async {
      final repository = FakePremiumRepository(
        session: _signedIn(),
        devices: LinkedDevices(
          maxDevices: 2,
          activeDevices: 2,
          devices: [
            PremiumDevice(
              deviceId: await FakePremiumRepository().deviceId(),
              deviceName: 'This phone',
            ),
            const PremiumDevice(deviceId: 'other', deviceName: 'Old tablet'),
          ],
        ),
      );
      final l10n = await pumpPanel(tester, repository);

      final card = tester.getRect(find.byType(PremiumDeviceRow).first);
      expect(
        tester.getRect(find.text(l10n.linkedDevices)).left,
        closeTo(card.left + AppLayout.premiumDeviceCardPad, 0.5),
      );
      expect(
        tester.getRect(find.text('2 / 2')).right,
        closeTo(card.right - AppLayout.premiumDeviceCardPad, 0.5),
      );
    });

    testWidgets('should raise nothing for a refresh that went through', (
      tester,
    ) async {
      final repository = FakePremiumRepository(session: _signedIn());
      final l10n = await pumpPanel(tester, repository);

      await press(tester, l10n.refresh);

      // The toast's own glyph: nothing else on the panel wears it.
      expect(find.byIcon(Iconsax.warning_2), findsNothing);

      await tester.pump(_pastTheToast);
    });
  });
}
