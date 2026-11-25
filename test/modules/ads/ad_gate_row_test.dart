import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/ads/presentation/states/post_connect_ad_state.dart';
import 'package:begzar/modules/ads/presentation/widgets/connection_overlays.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gate row holds the ad on screen and then lets go of it, and the whole
/// point of it being one row is that letting go costs the page nothing.
///
/// It used to cost the page 52dp. The wait was stated twice — a banner under
/// the header and a number in the corner — and the banner was dropped from the
/// column the moment the wait ended, which handed its height back to the
/// flexible above the copy and shoved the advertiser's picture upward at the
/// exact moment the reader was looking at it. Nothing about that was visible in
/// a still, which is why nothing caught it.
///
/// So this measures the two things that must not move: the picture, and the row
/// itself.
const _designSize = Size(393, 852);

/// The locales the app ships. The row states the wait as a distance rather than
/// a sentence, so it is the same width in all of them — but the badge beside it
/// is still a word, and a word is not.
const _locales = [Locale('en'), Locale('fa'), Locale('ru'), Locale('zh')];

/// Short enough to run out inside a test, long enough to have a middle.
const _waitSeconds = 3;

void _drawOn(WidgetTester tester, Size surface) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Advertisement _ad() {
  final now = DateTime.now();
  return Advertisement(
    id: 1,
    title: 'title',
    description: 'description',
    bannerUrl: 'https://example.invalid/banner.png',
    clickUrl: 'https://example.invalid/go',
    position: 'post_connect',
    priority: 1,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 1)),
    type: 'banner',
    action: 'action',
    buttonColor: '#7A3FD4',
    duration: _waitSeconds,
  );
}

/// Shows [ad] the way a post-connect gate does: content, and a wait to enforce.
class _ShowingAd extends PostConnectAdNotifier {
  _ShowingAd(this.ad);

  final Advertisement ad;

  @override
  PostConnectAdState? build() =>
      PostConnectAdState.ready(ad, enforceWait: true);
}

Widget _overlayIn(Locale locale, ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
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
        supportedLocales: _locales,
        home: const ConnectionOverlays(child: SizedBox.expand()),
      ),
    ),
  );
}

/// The capsule, found by the badge it carries rather than by its own type: it
/// is built by a private method, and the badge is the one part of it that is
/// named in every locale.
Rect _rowBox(WidgetTester tester) {
  return tester.getRect(
    find
        .ancestor(
          of: find.byIcon(Iconsax.star_1_copy),
          matching: find.byType(Padding),
        )
        .last,
  );
}

Rect _pictureBox(WidgetTester tester) {
  return tester.getRect(find.byType(CachedNetworkImage));
}

/// Runs the wait out, then lets the unlock settle. Deliberately not
/// `pumpAndSettle`: the banner's placeholder spins forever, so a settle here
/// would only ever time out.
Future<void> _runTheWaitOut(WidgetTester tester) async {
  for (var second = 0; second < _waitSeconds; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final locale in _locales) {
    testWidgets(
      'the ad does not move when the wait ends in ${locale.languageCode}',
      (tester) async {
        _drawOn(tester, _designSize);

        final container = ProviderContainer(
          overrides: [
            postConnectAdProvider.overrideWith(() => _ShowingAd(_ad())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_overlayIn(locale, container));
        container
            .read(connectionAdGateProvider.notifier)
            .start(seconds: _waitSeconds);
        await tester.pump();

        final rowWhileWaiting = _rowBox(tester);
        final pictureWhileWaiting = _pictureBox(tester);

        await _runTheWaitOut(tester);

        expect(
          container.read(connectionAdGateProvider).canClose,
          isTrue,
          reason: 'the wait has to have finished for the rest to mean anything',
        );
        expect(
          _pictureBox(tester),
          pictureWhileWaiting,
          reason:
              'the advertiser bought this rectangle; it cannot jump out from '
              'under the reader when the close control opens',
        );
        expect(
          _rowBox(tester),
          rowWhileWaiting,
          reason: 'the row is built once and never resized',
        );
      },
    );
  }

  testWidgets('the close control holds the count, then the way out', (
    tester,
  ) async {
    _drawOn(tester, _designSize);

    final container = ProviderContainer(
      overrides: [postConnectAdProvider.overrideWith(() => _ShowingAd(_ad()))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_overlayIn(const Locale('en'), container));
    container
        .read(connectionAdGateProvider.notifier)
        .start(seconds: _waitSeconds);
    await tester.pump();

    expect(find.text('$_waitSeconds'), findsOneWidget);
    expect(find.byIcon(Iconsax.close_circle_copy), findsNothing);

    await _runTheWaitOut(tester);

    expect(find.byIcon(Iconsax.close_circle_copy), findsOneWidget);
    expect(find.text('$_waitSeconds'), findsNothing);
  });

  testWidgets('an ad that enforces no wait opens already closable', (
    tester,
  ) async {
    _drawOn(tester, _designSize);

    final container = ProviderContainer(
      overrides: [postConnectAdProvider.overrideWith(() => _NoWaitAd(_ad()))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_overlayIn(const Locale('en'), container));
    await tester.pump();

    expect(find.byIcon(Iconsax.close_circle_copy), findsOneWidget);
  });
}

/// The other way the overlay is shown: an ad with no wait to enforce, which
/// never starts the gate at all.
class _NoWaitAd extends PostConnectAdNotifier {
  _NoWaitAd(this.ad);

  final Advertisement ad;

  @override
  PostConnectAdState? build() =>
      PostConnectAdState.ready(ad, enforceWait: false);
}
