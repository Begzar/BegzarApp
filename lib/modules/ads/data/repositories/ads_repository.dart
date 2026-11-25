import 'dart:convert';

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar/core/security/device_identity.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/ads/data/dtos/advertisement_dto.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// The one door to promotions (ads): the engine for the live list, secure
/// storage for the copy that survives a restart.
class AdsRepository {
  AdsRepository({
    AppKeyedStorage? storage,
    BegzarBackend? backend,
    DeviceIdentity? deviceIdentity,
  }) : _storage = storage ?? AppSecureStorage.instance,
       _backendOverride = backend,
       _deviceIdentityOverride = deviceIdentity;

  final AppKeyedStorage _storage;
  final BegzarBackend? _backendOverride;
  final DeviceIdentity? _deviceIdentityOverride;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  static const String cacheKeyAds = 'cached_ads';
  static const String cacheKeyExpiry = 'ads_expiry';

  /// How long a stored list stays usable. Past it the cache reads as empty and
  /// the caller falls back to fetching.
  static const Duration cacheTtl = Duration(hours: 24);

  /// Returns the server's list, or `null` when it could not be asked — no
  /// session key yet, a transport failure, or a non-OK result. `null` means
  /// "keep what you have"; an empty list means the server has no promotions.
  Future<List<Advertisement>?> getAds() async {
    try {
      final sessionToken = await ApiV2Service.readSessionToken();
      if (sessionToken == null) {
        return null;
      }
      final deviceId = await (_deviceIdentityOverride ?? DeviceIdentity())
          .getOrCreate();

      final BackendAnswer<List<BackendPromotion>> answer;
      try {
        answer = await _backend.fetchPromotions(
          sessionKey: sessionToken,
          deviceId: deviceId,
        );
      } on BackendException catch (e) {
        ReleaseHintBus.publish(e.releaseHint);
        return null;
      }
      ReleaseHintBus.publish(answer.releaseHint);
      final ads = _active(answer.value);
      await _writeCache(ads);
      return ads;
    } catch (_) {
      return null;
    }
  }

  /// Last stored list, so an ad is ready before the network answers.
  /// Empty when nothing was stored, the stamp lapsed, or the entry is unreadable.
  Future<List<Advertisement>> readCachedAds() async {
    try {
      final expiryRaw = await _storage.read(key: cacheKeyExpiry);
      if (expiryRaw == null) {
        return [];
      }
      final expiry = DateTime.tryParse(expiryRaw);
      if (expiry == null || DateTime.now().isAfter(expiry)) {
        return [];
      }

      final raw = await _storage.read(key: cacheKeyAds);
      if (raw == null) {
        return [];
      }
      final decoded = jsonDecode(raw);
      return decoded is List ? _parseAds(decoded) : [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<Advertisement> ads) async {
    try {
      await _storage.write(
        key: cacheKeyAds,
        value: jsonEncode(ads.map(AdvertisementDto.toJson).toList()),
      );
      await _storage.write(
        key: cacheKeyExpiry,
        value: DateTime.now().add(cacheTtl).toIso8601String(),
      );
    } catch (_) {}
  }

  /// The promotions to keep: the active ones, highest priority first. One
  /// whose dates do not parse costs the whole list, as it always has.
  List<Advertisement> _active(List<BackendPromotion> promotions) {
    final ads = promotions
        .map(AdvertisementDto.fromBackend)
        .where((ad) => ad.isActive)
        .toList();
    ads.sort((a, b) => b.priority.compareTo(a.priority));
    return ads;
  }

  List<Advertisement> _parseAds(List<dynamic> raw) {
    final ads = raw
        .whereType<Map>()
        .map(
          (adJson) =>
              AdvertisementDto.fromJson(Map<String, dynamic>.from(adJson)),
        )
        .where((ad) => ad.isActive)
        .toList();
    ads.sort((a, b) => b.priority.compareTo(a.priority));
    return ads;
  }

  Future<void> clearCache() async {
    try {
      await _storage.delete(key: cacheKeyAds);
      await _storage.delete(key: cacheKeyExpiry);
    } catch (_) {}
  }
}
