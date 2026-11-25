import 'dart:math';

import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';

/// How many of the highest-priority ads the next pick is drawn from.
const int _adRotationPoolSize = 3;

/// Ad Manager - Manages local ads
///
/// Holds the prepared ad between connects, so it is long-lived by nature. It
/// used to be a singleton reached for from wherever; `adManagerProvider` owns
/// the one the app uses now, which is the same lifetime with a seam in it.
class AdManager {
  AdManager(
    this._repository, {
    required Future<PurchaseRegion> Function() region,
    required String Function() language,
  }) : _region = region,
       _language = language;

  final AdsRepository _repository;

  /// Where the device is, which decides the language of the ad it is shown.
  final Future<PurchaseRegion> Function() _region;

  /// The app's language code, which an ad outside Iran is shown in first.
  final String Function() _language;

  final Random _random = Random();

  List<Advertisement> _localAds = [];
  Advertisement? _preparedAd;

  /// The ad the next connect will show, chosen ahead of time so the overlay
  /// can paint without a fetch. Re-checked on read because a stored ad can
  /// lapse while the app is open.
  Advertisement? get preparedAd {
    final ad = _preparedAd;
    if (ad == null || !ad.isActive) {
      return null;
    }
    return ad;
  }

  /// Initialize Ad Manager.
  ///
  /// Reads the stored list, and asks the server nothing. The list request is
  /// also how the backend records a successful connect, so it belongs to the
  /// connect path alone — see `ConnectionAdHandler.showAdAfterConnection`.
  /// Refreshing here would post a connect the user never made, on every
  /// launch.
  Future<void> initialize() async {
    try {
      _localAds = await _repository.readCachedAds();
      await prepareNextAd();
    } catch (_) {
      // Local ads are optional.
    }
  }

  /// Get a random local ad to display, in the version [region] reads with
  /// the app set to [language].
  ///
  /// Ads with no version for the reader drop out before the draw, so the
  /// rotation pool is filled from what this device can actually be shown.
  Advertisement? getRandomLocalAd(
    PurchaseRegion region, {
    required String language,
  }) {
    final sortedAds = [
      for (final ad in _localAds) ?ad.forRegion(region, language: language),
    ]..sort((a, b) => b.priority.compareTo(a.priority));
    if (sortedAds.isEmpty) return null;

    final topAds = sortedAds.take(_adRotationPoolSize).toList();

    // Return random from top ads
    return topAds[_random.nextInt(topAds.length)];
  }

  /// Picks the ad the next connect will show.
  Future<void> prepareNextAd() async {
    _preparedAd = getRandomLocalAd(await _region(), language: _language());
  }

  /// Refresh local ads.
  ///
  /// A `null` answer means the server could not be asked, so the current list
  /// and prepared ad are kept — a missing session key must not wipe them.
  Future<void> refreshLocalAds() async {
    try {
      final ads = await _repository.getAds();
      if (ads == null) return;
      _localAds = ads;
      await prepareNextAd();
    } catch (_) {
      // Local ads are optional.
    }
  }
}
