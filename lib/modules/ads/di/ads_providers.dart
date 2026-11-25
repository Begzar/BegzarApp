import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/network/begzar_image_cache.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/ads/application/services/ad_manager.dart';
import 'package:begzar/modules/ads/data/repositories/ads_repository.dart';
import 'package:begzar/modules/ads/presentation/ad_banner_prewarmer.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_handler.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the ad list is fetched and cached.
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(storage: ref.watch(flutterSecureStorageProvider));
});

/// Picks and holds the ad the next connect will show.
///
/// Long-lived on purpose: the prepared ad and the cached list are the whole
/// point, and dropping them between connects would put a fetch back on the
/// path this exists to keep clear.
///
/// Asks the purchase region where the device is, the same check the support
/// channel and the premium link answer to, so all three agree.
final adManagerProvider = Provider<AdManager>((ref) {
  return AdManager(
    ref.watch(adsRepositoryProvider),
    region: () {
      final status = ref.read(connectionProvider).status;
      return ref
          .read(purchaseRegionServiceProvider)
          .resolve(tunnelIsUp: status.isActive || status.isTransitional);
    },
    language: () => ref.read(localeProvider).languageCode,
  );
});

/// The disk cache ad banners are warmed into and painted from.
///
/// One provider for both, so the overlay always reads the cache the prewarmer
/// filled rather than relying on the two naming the same instance.
final adBannerCacheProvider = Provider<BaseCacheManager>((ref) {
  return BegzarImageCache.instance;
});

/// Pulls the next banner into the image cache ahead of time.
final adBannerPrewarmerProvider = Provider<AdBannerPrewarmer>((ref) {
  return AdBannerPrewarmer(ref.watch(adBannerCacheProvider));
});

/// The post-connect ad gate.
///
/// Takes [Ref] rather than being handed a `WidgetRef` per call: the gate is
/// driven from the connect path and from app lifecycle, and neither of those
/// is a widget.
final connectionAdHandlerProvider = Provider<ConnectionAdHandler>((ref) {
  return ConnectionAdHandler(
    ref,
    ref.watch(adManagerProvider),
    ref.watch(adBannerPrewarmerProvider),
    ref.watch(analyticsServiceProvider),
  );
});
