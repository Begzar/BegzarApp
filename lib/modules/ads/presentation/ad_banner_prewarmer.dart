import 'dart:async';

import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Pulls an ad banner into the image cache before the ad is shown, so the
/// overlay paints on its first frame instead of spinning on a download.
///
/// Mirrors [precacheImage], minus the `BuildContext` — warming happens from
/// service code that has no element to resolve a configuration against.
class AdBannerPrewarmer {
  AdBannerPrewarmer(this._cache);

  final BaseCacheManager _cache;

  String? _warmedUrl;

  /// Completes once the banner is decoded and in the cache, or once the
  /// download failed. A failure is not rethrown: the overlay still renders,
  /// it just falls back to its placeholder.
  Future<void> warm(Advertisement ad) async {
    if (_warmedUrl == ad.bannerUrl) return;

    final stream = CachedNetworkImageProvider(
      ad.bannerUrl,
      cacheManager: _cache,
    ).resolve(ImageConfiguration.empty);
    final completer = Completer<bool>();
    ImageStreamListener? listener;

    void finish(bool loaded) {
      if (!completer.isCompleted) {
        completer.complete(loaded);
      }
      // The listener may fire synchronously from addListener, so removal waits
      // for the frame to end rather than unwinding the call that added it.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        stream.removeListener(listener!);
      });
    }

    listener = ImageStreamListener(
      (_, _) => finish(true),
      onError: (_, _) => finish(false),
    );
    stream.addListener(listener);

    if (await completer.future) {
      _warmedUrl = ad.bannerUrl;
    }
  }
}
