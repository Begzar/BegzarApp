import 'dart:async';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/home_app_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/screens/premium_screen.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
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

/// The tab's own heading, spelled out rather than read back from the
/// localizations under test.
const _title = 'Premium';

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

/// Long enough for the toast to slide in.
const _toastSlideIn = Duration(milliseconds: 400);

/// Reports a fixed status without watching the service graph.
class _FixedConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.ready);
}

/// Signed out, which is the state that needs no services behind it.
class _FixedPremium extends PremiumNotifier {
  @override
  PremiumState build() => const PremiumSignedOut();
}

PremiumSession _signedIn() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);

void main() {
  /// Mounts the tab as the root screen shows it: signed out with nothing
  /// behind it, or against [repository] when a test needs the real
  /// controller to restore a session and act on it.
  Future<void> pumpPremium(
    WidgetTester tester, {
    FakePremiumRepository? repository,
  }) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionProvider.overrideWith(_FixedConnection.new),
          if (repository == null)
            premiumProvider.overrideWith(_FixedPremium.new)
          else ...[
            premiumRepositoryProvider.overrideWithValue(repository),
            analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
          ],
        ],
        child: ScreenUtilInit(
          designSize: _designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en')],
            home: PremiumScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PremiumScreen)));

  group('PremiumScreen', () {
    // The app bar used to belong to the home tab alone, so switching tabs
    // took the name, the plan and the channel button away with it.
    testWidgets('should open with the app bar every tab shares', (
      tester,
    ) async {
      await pumpPremium(tester);

      expect(find.byType(HomeAppBar), findsOneWidget);
    });

    // The tab is already named by its selected icon in the nav bar, so a
    // heading under the app bar only pushed the account panel down.
    testWidgets('should not show a title under the app bar', (tester) async {
      await pumpPremium(tester);

      expect(find.text(_title), findsNothing);
    });

    // The nav bar floats over the foot of the tab, so scrolled all the way
    // down the tab's last content has to sit above the bar, not under it.
    testWidgets('should scroll the last content clear of the nav bar', (
      tester,
    ) async {
      await pumpPremium(tester);

      // The tab's own scroll view, outside any the form nests in it.
      final scrollView = find.byType(SingleChildScrollView).first;
      final list = tester.state<ScrollableState>(
        find
            .descendant(of: scrollView, matching: find.byType(Scrollable))
            .first,
      );
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final body = tester.widget<SingleChildScrollView>(scrollView).child!;
      final barTop =
          _designSize.height - (NavBar.bottomInset + NavBar.height).w;
      expect(tester.getRect(find.byWidget(body)).bottom, lessThan(barTop));
    });
  });

  // The form reports its own refusal once the answer is in, so it has to be
  // the same form when the answer arrives. The tab used to swap it for a
  // spinner while signing in, which took the toast and the typed fields with
  // it.
  group('PremiumScreen and a sign-in', () {
    testWidgets('should report a refusal and keep what was typed', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpPremium(
        tester,
        repository: FakePremiumRepository(
          signInResult: left(const RateLimitFailure('quota')),
        )..signInGate = gate,
      );
      final l10n = l10nOf(tester);
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      await tester.enterText(find.byType(TextField).at(0), 'user');
      await tester.enterText(find.byType(TextField).at(1), 'secret-password');
      // The switch above the form carries the same words.
      final button = find.widgetWithText(PremiumPrimaryButton, l10n.signIn);
      await tester.ensureVisible(button);
      await tester.tap(button);
      // A frame drawn while the server has not answered yet.
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump(_toastSlideIn);

      expect(find.text(error.message), findsOneWidget);
      expect(find.text('user'), findsOneWidget);

      await tester.pump(_pastTheToast);
    });
  });

  // Nothing the user pressed asks whether the seat is still theirs: the launch
  // refresh, opening the tab or the device list finds out. So the screen
  // raises the toast itself, on the change into signed out.
  group('PremiumScreen and a seat the server took away', () {
    testWidgets('should report it in the error toast and nowhere else', (
      tester,
    ) async {
      await pumpPremium(
        tester,
        repository: FakePremiumRepository(
          session: _signedIn(),
          refreshResult: left(const SessionRevokedFailure()),
        ),
      );
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.deviceRemoved,
        l10nOf(tester),
      );

      expect(find.text(error.message), findsOneWidget);
      expect(find.text(error.hint!), findsOneWidget);
      expect(
        find.byType(PremiumErrorBanner),
        findsNothing,
        reason: 'the sign-in form used to keep the reason above itself',
      );

      await tester.pump(_pastTheToast);
    });

    // Deleting an account ends the session the same way, and carries no
    // reason: the user asked for it. A toast raised for no reason reads as
    // the generic connection failure.
    testWidgets('should raise nothing for an account the user deleted', (
      tester,
    ) async {
      await pumpPremium(
        tester,
        repository: FakePremiumRepository(session: _signedIn()),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PremiumScreen)),
      );

      await container
          .read(premiumProvider.notifier)
          .deleteAccount('secret-password');
      await tester.pump();
      await tester.pump();
      await tester.pump(_toastSlideIn);

      expect(container.read(premiumProvider), isA<PremiumSignedOut>());
      // The toast's own glyph: nothing on the sign-in form wears it.
      expect(find.byIcon(Iconsax.warning_2), findsNothing);
    });
  });
}
