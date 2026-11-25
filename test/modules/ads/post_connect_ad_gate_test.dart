import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:begzar/modules/ads/di/ads_providers.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/ad_banner_prewarmer.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';
import '../../support/recording_analytics.dart';
import '../premium/premium_test_doubles.dart';

/// Who the post-connect ad is for, and how often.
///
/// Three rules: a subscriber never sees one, a free user sees one per connect,
/// and a tunnel this app merely found is not a connect.
void main() {
  final cameUpAt = DateTime.utc(2026, 9, 5, 14, 30);

  ConnectionEntity dialled({DateTime? at}) =>
      ConnectionEntity.create().connected(at: at ?? cameUpAt);

  ConnectionEntity adopted() =>
      ConnectionEntity.create().connected(at: cameUpAt, adopted: true);

  testWidgets('a free user is shown the ad on a connect', (tester) async {
    final container = await _container();

    final gate = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNotNull);
    await _finish(container, gate);
  });

  // Reopening the app over a live tunnel reaches connected by the same
  // transition a connect does. It used to be charged an ad for a session that
  // had already paid for one.
  testWidgets('a tunnel found rather than dialled is not gated', (
    tester,
  ) async {
    final container = await _container();

    final gate = await _startGate(tester, container, adopted());

    expect(container.read(postConnectAdProvider), isNull);
    await _finish(container, gate);
  });

  testWidgets('one tunnel is gated once, however often it reconnects', (
    tester,
  ) async {
    final container = await _container();

    final first = await _startGate(tester, container, dialled());
    expect(container.read(postConnectAdProvider), isNotNull);
    await _finish(container, first);

    // A health-check probe that answered "down" and then "up" again lands
    // right back on connected without the tunnel ever having dropped.
    final second = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNull);
    await _finish(container, second);
  });

  testWidgets('a genuinely new tunnel is gated again', (tester) async {
    final container = await _container();

    final first = await _startGate(tester, container, dialled());
    await _finish(container, first);

    final second = await _startGate(
      tester,
      container,
      dialled(at: cameUpAt.add(const Duration(minutes: 5))),
    );

    expect(container.read(postConnectAdProvider), isNotNull);
    await _finish(container, second);
  });

  testWidgets('a subscriber is never shown an ad', (tester) async {
    final container = await _container(session: _subscriber());

    final gate = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNull);
    await _finish(container, gate);
  });

  // The regression. `PremiumRestoring` carries no account, so a launch that
  // reached the gate before the stored session had been read answered the
  // entitlement question exactly as a signed-out user would have.
  testWidgets('a subscriber whose session is still being restored is not', (
    tester,
  ) async {
    // Deliberately not settled first: this is the launch race.
    final container = _rawContainer(session: _subscriber());

    final gate = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNull);
    await _finish(container, gate);
  });

  testWidgets('a lapsed subscription is a free user again', (tester) async {
    final container = await _container(session: _lapsed());

    final gate = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNotNull);
    await _finish(container, gate);
  });

  testWidgets('ads turned off in settings stay off', (tester) async {
    final container = await _container();
    await container.read(settingsProvider.notifier).setAdsBlock(true);

    final gate = await _startGate(tester, container, dialled());

    expect(container.read(postConnectAdProvider), isNull);
    await _finish(container, gate);
  });

  // The promotions list is also the backend's record of a successful connect —
  // it stamps the session row the stats dashboard counts as active. So the
  // request follows the connect: once, after the tunnel is up, before anything
  // is on screen, and never again for the same tunnel.
  testWidgets('a gated connect asks for the list once, before the overlay', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    final container = await _container(adsRepository: repository);
    final primed = repository.getAdsCalls;
    Object? overlayWhenAsked = _nothingAsked;
    repository.onGetAds = () =>
        overlayWhenAsked = container.read(postConnectAdProvider);

    final gate = await _startGate(tester, container, dialled());

    expect(repository.getAdsCalls, primed + 1);
    expect(overlayWhenAsked, isNull, reason: 'asked before the overlay');

    await _finish(container, gate);
    await tester.pump();

    expect(
      repository.getAdsCalls,
      primed + 1,
      reason: 'the dismissal must not post a second connect',
    );
  });

  testWidgets('a connect nobody is gated for asks for nothing', (tester) async {
    final repository = _FakeAdsRepository();
    final container = await _container(
      session: _subscriber(),
      adsRepository: repository,
    );
    final primed = repository.getAdsCalls;

    final gate = await _startGate(tester, container, dialled());
    await _finish(container, gate);
    await tester.pump();

    expect(repository.getAdsCalls, primed);
  });

  testWidgets('a tunnel found rather than dialled asks for nothing', (
    tester,
  ) async {
    final repository = _FakeAdsRepository();
    final container = await _container(adsRepository: repository);
    final primed = repository.getAdsCalls;

    final gate = await _startGate(tester, container, adopted());
    await _finish(container, gate);
    await tester.pump();

    expect(repository.getAdsCalls, primed);
  });

  // Which way the ad arrived is the prewarm's health: a prepared ad paints at
  // once, a fetched one sat behind the shimmer while the list came back.
  testWidgets('an ad picked before the connect is recorded as prepared', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = await _container(analytics: analytics);

    final gate = await _startGate(tester, container, dialled());

    expect(analytics.callsTo(#logPromotionViewed), [
      {
        #promotionId: 1,
        #promotionName: 'ad',
        #source: PromotionSource.prepared,
      },
    ]);
    await _finish(container, gate);
  });

  testWidgets('an ad fetched during the connect is recorded as fetched', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    // Settled, but with no list read yet: a cold install's first connect.
    final container = _rawContainer(analytics: analytics);
    await container.read(premiumProvider.notifier).ensureRestored();
    await container.read(settingsProvider.notifier).ensureLoaded();

    final gate = await _startGate(tester, container, dialled());
    await tester.pump();

    expect(analytics.callsTo(#logPromotionViewed), [
      {#promotionId: 1, #promotionName: 'ad', #source: PromotionSource.fetched},
    ]);
    await _finish(container, gate);
  });

  testWidgets('a gated connect with nothing to show records that', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = await _container(
      analytics: analytics,
      adsRepository: _FakeAdsRepository(ads: const []),
    );

    final gate = await _startGate(tester, container, dialled());
    await gate.done;

    expect(analytics.callsTo(#logPromotionUnavailable), hasLength(1));
    expect(analytics.callsTo(#logPromotionViewed), isEmpty);
  });

  testWidgets('a subscriber\'s connect records no promotion at all', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = await _container(
      session: _subscriber(),
      analytics: analytics,
    );

    final gate = await _startGate(tester, container, dialled());
    await _finish(container, gate);

    expect(analytics.callsTo(#logPromotionViewed), isEmpty);
    expect(analytics.callsTo(#logPromotionUnavailable), isEmpty);
  });
}

/// Distinguishes "the list was never asked for" from "it was asked for with
/// nothing on screen", which are both `null` on the provider.
const Object _nothingAsked = Object();

/// One run of the gate, held rather than awaited.
///
/// A gate that decides to show something waits for a dismissal, so awaiting
/// the call before asserting would hang a broken gate rather than fail it.
class _Gate {
  const _Gate(this.done);

  final Future<void> done;
}

/// Fires the gate and lets it get as far as it is going to.
Future<_Gate> _startGate(
  WidgetTester tester,
  ProviderContainer container,
  ConnectionEntity connection,
) async {
  final done = container
      .read(connectionAdHandlerProvider)
      .showAdAfterConnection(connection);
  await tester.pump();
  return _Gate(done);
}

/// Dismisses whatever is on screen and lets the gate unwind.
Future<void> _finish(ProviderContainer container, _Gate gate) async {
  container.read(postConnectAdProvider.notifier).dismiss();
  await gate.done;
}

PremiumSession _subscriber() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);

PremiumSession _lapsed() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String(),
    statusLabel: 'true',
  ),
);

ProviderContainer _rawContainer({
  PremiumSession? session,
  _FakeAdsRepository? adsRepository,
  RecordingAnalytics? analytics,
}) {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(MemoryKeyedStorage()),
      adsRepositoryProvider.overrideWithValue(
        adsRepository ?? _FakeAdsRepository(),
      ),
      adBannerPrewarmerProvider.overrideWithValue(const _NoopPrewarmer()),
      premiumRepositoryProvider.overrideWithValue(
        FakePremiumRepository(session: session),
      ),
      // The ad manager asks where the device is before every pick.
      purchaseRegionRepositoryProvider.overrideWithValue(
        FakePurchaseRegionRepository(),
      ),
      analyticsServiceProvider.overrideWithValue(
        analytics ?? RecordingAnalytics(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A container whose premium restore, ad list and settings have all settled,
/// so a test is about the gate rather than about what had loaded when it ran.
Future<ProviderContainer> _container({
  PremiumSession? session,
  _FakeAdsRepository? adsRepository,
  RecordingAnalytics? analytics,
}) async {
  final container = _rawContainer(
    session: session,
    adsRepository: adsRepository,
    analytics: analytics,
  );
  await container.read(premiumProvider.notifier).ensureRestored();
  await container.read(adManagerProvider).refreshLocalAds();
  await container.read(settingsProvider.notifier).ensureLoaded();
  return container;
}

class _FakeAdsRepository implements AdsRepository {
  _FakeAdsRepository({List<Advertisement>? ads}) : _ads = ads ?? _oneAd;

  final List<Advertisement> _ads;

  /// How often the server was asked for the list. That request is what the
  /// backend records as a successful connect, so the count is the assertion.
  int getAdsCalls = 0;

  /// Runs at the moment the list is asked for, so a test can see what was on
  /// screen at the time.
  void Function()? onGetAds;

  @override
  Future<List<Advertisement>> readCachedAds() async => _ads;

  @override
  Future<List<Advertisement>?> getAds() async {
    getAdsCalls++;
    onGetAds?.call();
    return _ads;
  }

  @override
  Future<void> clearCache() async {}

  static final _oneAd = <Advertisement>[
    Advertisement(
      id: 1,
      title: 'ad',
      description: 'description',
      bannerUrl: 'https://example.invalid/1.png',
      clickUrl: 'https://example.invalid/1',
      position: 'post_connect',
      priority: 1,
      startDate: DateTime(2000),
      endDate: DateTime(2099),
      type: 'banner',
      action: 'view',
      buttonColor: '#FFA500',
      duration: 15,
    ),
  ];
}

/// The real one decodes over the network, which a test has no business doing.
class _NoopPrewarmer implements AdBannerPrewarmer {
  const _NoopPrewarmer();

  @override
  Future<void> warm(Advertisement ad) async {}
}
