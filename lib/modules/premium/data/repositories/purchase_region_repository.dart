import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/backend_failure.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

/// Reads where the device is, so a purchase can be sent to the right place.
///
/// The one request it makes goes to the Begzar API, which sees the address on
/// every call anyway. The public geo services the exit pill falls back to are
/// never asked: they would learn the real address of someone who installed a
/// VPN to keep it to themselves.
///
/// The server's answer is kept in secure storage so a launch need not ask it
/// again; nothing the device itself reports is stored.
class PurchaseRegionRepository {
  PurchaseRegionRepository({
    required AppKeyedStorage storage,
    MethodChannel channel = const MethodChannel(
      'cloud.begzar.begzar/device_info',
    ),
    Duration Function()? utcOffset,
    Locale Function()? systemLocale,
    BegzarBackend? backend,
  }) : _storage = storage,
       _channel = channel,
       _utcOffset = utcOffset ?? (() => DateTime.now().timeZoneOffset),
       _systemLocale =
           systemLocale ?? (() => PlatformDispatcher.instance.locale),
       _backendOverride = backend;

  static const _addressKey = 'purchase_address_v1';

  final AppKeyedStorage _storage;
  final MethodChannel _channel;
  final Duration Function() _utcOffset;
  final Locale Function() _systemLocale;
  final BegzarBackend? _backendOverride;

  BegzarBackend get _backend => _backendOverride ?? BegzarEngine.ins.backend;

  Future<DeviceRegionSignals> readDevice() async {
    final native = await _askPlatform();
    final locale = _systemLocale();
    return DeviceRegionSignals(
      utcOffset: _utcOffset(),
      timeZoneId: native['timeZoneId'],
      localeLanguage: locale.languageCode,
      localeRegion: locale.countryCode,
      simCountry: native['simCountry'],
      networkCountry: native['networkCountry'],
    );
  }

  /// Only Android answers. Everywhere else the channel has no such method, and
  /// that reads as each of these readings being silent — not as a failure.
  Future<Map<String, String>> _askPlatform() async {
    try {
      final answer = await _channel.invokeMapMethod<String, Object?>(
        'getRegionSignals',
      );
      return {
        for (final MapEntry(:key, :value) in (answer ?? const {}).entries)
          if (value is String && value.trim().isNotEmpty) key: value.trim(),
      };
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  /// The country the Begzar API places this device's address in.
  ///
  /// A right of null is the server answering without a country; a left is the
  /// server not being reached, or refusing.
  Future<Either<ApiFailure, String?>> addressCountry() async {
    try {
      return right((await _backend.lookupRegionCountry()).value);
    } on BackendException catch (e) {
      return left(
        apiFailureFromBackend(
          e,
          unexpectedKey: UserFacingErrorKeys.networkError,
        ),
      );
    } catch (e) {
      return left(
        UnexpectedFailure(
          'Address country lookup threw',
          userFacingKey: UserFacingErrorKeys.networkError,
          cause: e,
        ),
      );
    }
  }

  /// The answer [storeAddressAnswer] last kept, or null when there is none.
  ///
  /// Storage that will not answer, or holds something unreadable, reads as
  /// nothing kept: the cost is one request, which is what a cold install
  /// makes anyway.
  Future<AddressAnswer?> readAddressAnswer() async {
    try {
      final raw = await _storage.read(key: _addressKey);
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final askedAt = DateTime.tryParse('${map['at']}');
      final country = map['country'];
      if (askedAt == null || (country != null && country is! String)) {
        return null;
      }
      return AddressAnswer(country: country as String?, askedAt: askedAt);
    } catch (_) {
      return null;
    }
  }

  /// Keeps [answer] for the next launch. A write that fails is dropped: the
  /// answer still holds for this run, and the next launch asks again.
  Future<void> storeAddressAnswer(AddressAnswer answer) async {
    try {
      await _storage.write(
        key: _addressKey,
        value: jsonEncode({
          'country': answer.country,
          'at': answer.askedAt.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // See above.
    }
  }
}
