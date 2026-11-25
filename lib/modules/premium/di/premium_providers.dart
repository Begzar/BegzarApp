import 'dart:io';

import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/providers/api_provider.dart';
import 'package:begzar/modules/premium/application/services/google_play_purchase_service.dart';
import 'package:begzar/modules/premium/application/services/premium_account_service.dart';
import 'package:begzar/modules/premium/application/services/premium_servers_service.dart';
import 'package:begzar/modules/premium/application/services/purchase_region_service.dart';
import 'package:begzar/modules/premium/data/datasources/google_play_billing_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:begzar/modules/premium/data/repositories/google_play_billing_repository.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/data/repositories/purchase_region_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The premium module's composition root.
///
/// This is the only place that knows both the Riverpod container and the
/// module's data layer, which is what lets everything below it be built with
/// plain constructors and faked in a test by overriding one provider.
///
/// Each controller declares its own `NotifierProvider` beside itself; what
/// lives here is the graph underneath them.

/// Secure-storage-backed local data source.
final premiumStorageProvider = Provider<PremiumStorage>((ref) {
  return PremiumStorage(storage: ref.watch(flutterSecureStorageProvider));
});

/// The premium backend, through the engine's operations. The device's own
/// session, which sign-up is signed with, comes from the same place the free
/// tier's does.
final premiumRemoteDataSourceProvider = Provider<PremiumRemoteDataSource>((
  ref,
) {
  return PremiumRemoteDataSource(
    ensureSessionToken: ref.watch(apiV2ServiceProvider).ensureSessionToken,
  );
});

/// The one door to premium data. Tests override this rather than the two
/// sources beneath it.
final premiumRepositoryProvider = Provider<PremiumRepository>((ref) {
  return PremiumRepository(
    remote: ref.watch(premiumRemoteDataSourceProvider),
    storage: ref.watch(premiumStorageProvider),
  );
});

/// Session, entitlement and devices.
final premiumAccountServiceProvider = Provider<PremiumAccountService>((ref) {
  return PremiumAccountService(ref.watch(premiumRepositoryProvider));
});

/// The server list and its pings.
final premiumServersServiceProvider = Provider<PremiumServersService>((ref) {
  return PremiumServersService(ref.watch(premiumRepositoryProvider));
});

/// Where the device says it is. Tests override this rather than the channel
/// and the geo client beneath it.
final purchaseRegionRepositoryProvider = Provider<PurchaseRegionRepository>((
  ref,
) {
  return PurchaseRegionRepository(
    storage: ref.watch(flutterSecureStorageProvider),
  );
});

/// Which side of the border a buyer is on. One per container, because it holds
/// the address's answer for the rest of the run once it has one.
final purchaseRegionServiceProvider = Provider<PurchaseRegionService>((ref) {
  return PurchaseRegionService(
    ref.watch(purchaseRegionRepositoryProvider),
    tunnelCarriesOwnTraffic: Platform.isIOS || Platform.isMacOS,
  );
});

/// Google Play Billing. Built only when a Play build asks for it.
final googlePlayBillingDataSourceProvider =
    Provider<GooglePlayBillingDataSource>(
      (ref) => GooglePlayBillingDataSource(),
    );

/// The paywall's door to Play. Tests override this rather than the plugin.
final googlePlayBillingRepositoryProvider =
    Provider<GooglePlayBillingRepository>((ref) {
      return GooglePlayBillingRepository(
        billing: ref.watch(googlePlayBillingDataSourceProvider),
        remote: ref.watch(premiumRemoteDataSourceProvider),
      );
    });

/// Sells through Play and sees each purchase through, for the whole run.
final googlePlayPurchaseServiceProvider = Provider<GooglePlayPurchaseService>((
  ref,
) {
  final service = GooglePlayPurchaseService(
    billing: ref.watch(googlePlayBillingRepositoryProvider),
    premium: ref.watch(premiumRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
