import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/ads/di/ads_providers.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/ads/presentation/states/post_connect_ad_state.dart';
import 'package:begzar/modules/ads/presentation/widgets/connection_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/coloured_shadows.dart';
import '../../../../support/recording_analytics.dart';

const _designSize = Size(393, 852);

const _waitSeconds = 3;

/// The channel `url_launcher` answers on when no platform plugin registered
/// itself, which is the case under test.
const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

Advertisement _ad({
  String title = 'title',
  String description = 'description',
}) {
  final now = DateTime.now();
  return Advertisement(
    id: 7,
    title: title,
    description: description,
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

/// Shows an ad the way a post-connect gate does, with or without a wait.
class _ShowingAd extends PostConnectAdNotifier {
  _ShowingAd({required this.enforceWait, required this.ad});

  final bool enforceWait;
  final Advertisement ad;

  @override
  PostConnectAdState? build() =>
      PostConnectAdState.ready(ad, enforceWait: enforceWait);
}

void _drawOn(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _designSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

/// Answers every launch on the plugin channel with [opened].
void _launcherAnswers(WidgetTester tester, {required bool opened}) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_urlLauncherChannel, (_) async => opened);
  addTearDown(
    () => messenger.setMockMethodCallHandler(_urlLauncherChannel, null),
  );
}

Future<ProviderContainer> _pumpOverlay(
  WidgetTester tester, {
  required RecordingAnalytics analytics,
  required bool enforceWait,
  Advertisement? ad,
  Locale locale = const Locale('en'),
}) async {
  _drawOn(tester);
  final container = ProviderContainer(
    overrides: [
      postConnectAdProvider.overrideWith(
        () => _ShowingAd(enforceWait: enforceWait, ad: ad ?? _ad()),
      ),
      adBannerCacheProvider.overrideWithValue(_FailingBannerCache()),
      analyticsServiceProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('fa')],
          // A link that would not open says so in a snack bar, which needs a
          // scaffold under the overlay as the app has.
          home: const ConnectionOverlays(child: Scaffold()),
        ),
      ),
    ),
  );
  if (enforceWait) {
    container
        .read(connectionAdGateProvider.notifier)
        .start(seconds: _waitSeconds);
  }
  await tester.pump();
  return container;
}

/// Runs the countdown to zero, so its timer is not left behind the test.
Future<void> _runTheWaitOut(WidgetTester tester) async {
  for (var second = 0; second <= _waitSeconds; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// A banner cache whose every download fails, the way a 404 or a dead CDN
/// does on a device.
class _FailingBannerCache implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.error(const HttpExceptionWithStatus(404, 'Not found'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ConnectionOverlays', () {
    testWidgets('should record a tap during the wait as selected mid-wait', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      _launcherAnswers(tester, opened: false);
      await _pumpOverlay(tester, analytics: analytics, enforceWait: true);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await _runTheWaitOut(tester);

      expect(analytics.callsTo(#logPromotionSelected), [
        {
          #promotionId: 7,
          #promotionName: 'title',
          #duringWait: true,
          #opened: false,
        },
      ]);
    });

    testWidgets('should record a tap that opened the link as opened', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      _launcherAnswers(tester, opened: true);
      await _pumpOverlay(tester, analytics: analytics, enforceWait: false);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(analytics.callsTo(#logPromotionSelected), [
        {
          #promotionId: 7,
          #promotionName: 'title',
          #duringWait: false,
          #opened: true,
        },
      ]);
    });

    // The promotion's action is drawn in its own colour as a solid fill, like
    // every other primary button; a glow on this app marks a state.
    testWidgets("should draw no glow under the promotion's action", (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        analytics: RecordingAnalytics(),
        enforceWait: false,
      );

      final fill = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    (widget.decoration as BoxDecoration?)?.gradient != null,
              ),
            )
            .first,
      );

      expect(
        (fill.decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[],
        isEmpty,
      );
    });

    // The rail says how long is left by how far it has filled; a glow round it
    // while it runs was a halo on top of that.
    testWidgets('should draw the countdown rail without a glow', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        analytics: RecordingAnalytics(),
        enforceWait: true,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        colouredShadowsUnder(tester, find.byType(ConnectionOverlays)),
        isEmpty,
      );

      await _runTheWaitOut(tester);
    });

    // The countdown rebuilds the overlay every second. A failure recorded from
    // the build would be counted once per tick rather than once per banner.
    testWidgets('should record a banner that failed to load once', (
      tester,
    ) async {
      final analytics = RecordingAnalytics();
      await _pumpOverlay(tester, analytics: analytics, enforceWait: true);

      await _runTheWaitOut(tester);

      expect(analytics.callsTo(#logPromotionBannerFailed), [
        {#promotionId: 7, #promotionName: 'title'},
      ]);
    });

    // The card reads in the ad's own script, whatever language the app is in.
    testWidgets('should lay an English ad out left to right in a Persian app', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        analytics: RecordingAnalytics(),
        enforceWait: false,
        locale: const Locale('fa'),
        ad: _ad(title: 'Telegram channel', description: 'Join the channel'),
      );

      final title = tester.element(find.text('Telegram channel'));

      expect(Directionality.of(title), TextDirection.ltr);
    });

    testWidgets('should lay a Persian ad out right to left in an English app', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        analytics: RecordingAnalytics(),
        enforceWait: false,
        ad: _ad(title: 'کانال تلگرام', description: 'عضو کانال شوید'),
      );

      final title = tester.element(find.text('کانال تلگرام'));

      expect(Directionality.of(title), TextDirection.rtl);
    });
  });
}
