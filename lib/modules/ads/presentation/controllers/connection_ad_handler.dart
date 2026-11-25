import 'dart:async';

import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/ads/application/services/ad_manager.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/ad_banner_prewarmer.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connection Ad Handler
/// Handles showing ads after successful VPN connection
///
/// Reached through `connectionAdHandlerProvider`. It used to be a singleton
/// that took a `WidgetRef` on every call, which meant the gate could only run
/// while some particular widget was alive to lend it one; it holds the
/// container's own [Ref] now and needs nothing from its caller.
class ConnectionAdHandler {
  ConnectionAdHandler(
    this._ref,
    this._adManager,
    this._prewarmer,
    this._analytics,
  );

  final Ref _ref;
  final AdManager _adManager;
  final AdBannerPrewarmer _prewarmer;
  final AnalyticsService _analytics;

  /// The tunnel session an ad has already run for, identified by its start.
  ///
  /// The gate hangs off the transition into connected, and one tunnel can
  /// produce that transition more than once in a process: a health-check
  /// probe that briefly answers "down" and then "up" again lands right back on
  /// connected without the tunnel ever having dropped. One ad per connect
  /// means one ad per tunnel, so the session is what is remembered.
  DateTime? _gatedSession;

  /// True while a gate is running, so a second transition cannot stack a
  /// second overlay on the first.
  bool _running = false;

  /// Records [ad] as on screen, without holding the overlay up for it.
  void _recordViewed(Advertisement ad, PromotionSource source) {
    unawaited(
      _analytics.logPromotionViewed(
        promotionId: ad.id,
        promotionName: ad.title,
        source: source,
      ),
    );
  }

  /// Show ad after connection.
  ///
  /// An ad prepared ahead of time is painted straight away. Only when nothing
  /// is prepared — first launch, or a lapsed cache — does the shimmer shell
  /// stand in while the list is fetched.
  ///
  /// This is also the one place the promotions list is asked for, because that
  /// request is what the backend counts as a successful connect. It is made
  /// once the tunnel is up and before anything is on screen, so the count
  /// follows connects rather than launches or ad dismissals.
  ///
  /// [connection] must be the state that just reached connected. A tunnel this
  /// app adopted rather than dialled is not a connect the user performed, so it
  /// is not gated — reopening the app on a live tunnel used to show an ad for a
  /// session that had already paid for one.
  Future<void> showAdAfterConnection(ConnectionEntity connection) async {
    if (connection.adopted || _running) return;

    final session = connection.connectedAt;
    if (session != null && session == _gatedSession) return;

    final ref = _ref;
    final settingsNotifier = ref.read(settingsProvider.notifier);
    if (settingsNotifier.shouldBlockAds) {
      return;
    }

    // A launch restore that has not landed yet reads as signed out, which
    // would put an ad in front of a subscriber.
    await ref.read(premiumProvider.notifier).ensureRestored();
    if (ref.read(premiumProvider).hasActiveSubscription) {
      return;
    }

    _running = true;
    _gatedSession = session;
    final adNotifier = ref.read(postConnectAdProvider.notifier);
    final gateNotifier = ref.read(connectionAdGateProvider.notifier);

    // The connect is now real and nothing is on screen yet: the moment the
    // list request stands for. It is not awaited on the fast path — what it
    // answers is the ad the *next* connect will show, and this one already has
    // one prepared and warmed.
    final listRequest = _adManager.refreshLocalAds();

    try {
      final prepared = _adManager.preparedAd;
      if (prepared != null) {
        gateNotifier.start(seconds: prepared.duration);
        final wait = adNotifier.showAndWait(prepared, enforceWait: true);
        _recordViewed(prepared, PromotionSource.prepared);
        await wait;
        return;
      }

      // Nothing prepared. The shimmer stands in until that same request
      // answers — a second one would post a second connect.
      final waitFuture = adNotifier.showLoadingAndWait();
      await listRequest;
      final fetched = _adManager.preparedAd;
      if (fetched == null) {
        adNotifier.dismiss();
        unawaited(_analytics.logPromotionUnavailable());
        return;
      }

      adNotifier.showContent(fetched, enforceWait: true);
      gateNotifier.start(seconds: fetched.duration);
      _recordViewed(fetched, PromotionSource.fetched);
      await waitFuture;
    } catch (e) {
      adNotifier.dismiss();
    } finally {
      _running = false;
      gateNotifier.complete();
      if (ref.read(postConnectAdProvider) != null) {
        adNotifier.dismiss();
      }
      unawaited(listRequest.then((_) => _warmNextBanner()));
    }
  }

  /// Warm the next connect's banner while the tunnel is up, so the following
  /// overlay paints without a download. Best-effort; a failure leaves the
  /// banner to load on screen.
  ///
  /// Picks from the answer to this connect's list request rather than making
  /// one of its own, which is why it is chained onto that future: asking again
  /// here would post a second connect for the same tunnel.
  Future<void> _warmNextBanner() async {
    try {
      final next = _adManager.preparedAd;
      if (next != null) {
        await _prewarmer.warm(next);
      }
    } catch (_) {
      // Prefetch is best-effort.
    }
  }

  /// Initialize (delegates to AdManager, then warms the first banner)
  Future<void> initialize() async {
    await _adManager.initialize();
    final ad = _adManager.preparedAd;
    if (ad != null) {
      unawaited(_prewarmer.warm(ad));
    }
  }
}
