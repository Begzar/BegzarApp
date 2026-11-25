import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendPromotion;

/// Wire and cache format for [Advertisement].
///
/// The server names its fields in snake_case and has sent promotions without
/// an `action`, `button_color` or a sane `duration`, so every optional field
/// carries a default rather than failing the whole list.
abstract final class AdvertisementDto {
  /// Fallback call-to-action label when the server omits one.
  static const String _defaultAction = 'مشاهده';

  /// Fallback call-to-action colour when the server omits one.
  static const String _defaultButtonColor = '#FFA500';

  /// How long the overlay holds when the server sends no usable duration.
  static const int _defaultDurationSeconds = 15;

  /// Bounds a server-sent duration: long enough to read, short enough that a
  /// bad value cannot lock the overlay open.
  static const int _minDurationSeconds = 1;
  static const int _maxDurationSeconds = 300;

  static Advertisement fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      bannerUrl: json['banner_url'] as String,
      clickUrl: json['click_url'] as String,
      position: json['position'] as String,
      priority: json['priority'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      type: json['type'] as String,
      action: (json['action'] as String?) ?? _defaultAction,
      buttonColor: (json['button_color'] as String?) ?? _defaultButtonColor,
      duration: _parseDuration(json['duration']),
      byLanguage: _parseByLanguage(json[_byLanguageField]),
    );
  }

  /// A promotion as the engine read it. A date that does not parse throws,
  /// failing the list it came in; a language's version that does not is left
  /// out.
  static Advertisement fromBackend(BackendPromotion p) {
    return Advertisement(
      id: p.id,
      title: p.title,
      description: p.description,
      bannerUrl: p.bannerUrl,
      clickUrl: p.clickUrl,
      position: p.position,
      priority: p.priority,
      startDate: DateTime.parse(p.startDate),
      endDate: DateTime.parse(p.endDate),
      type: p.type,
      action: p.action ?? _defaultAction,
      buttonColor: p.buttonColor ?? _defaultButtonColor,
      duration: _parseDuration(p.duration),
      byLanguage: {
        for (final MapEntry(:key, value: version) in p.byLanguage.entries)
          key: ?_tryFromBackend(version),
      },
    );
  }

  static Advertisement? _tryFromBackend(BackendPromotion p) {
    try {
      return fromBackend(p);
    } catch (_) {
      return null;
    }
  }

  static const String _byLanguageField = 'by_lang';

  /// A version that is not an object, or will not parse, is left out rather
  /// than failing the ad it belongs to.
  static Map<String, Advertisement> _parseByLanguage(dynamic value) {
    if (value is! Map) return const {};
    final versions = <String, Advertisement>{};
    for (final MapEntry(:key, value: version) in value.entries) {
      if (version is! Map) continue;
      try {
        versions['$key'] = fromJson(Map<String, dynamic>.from(version));
      } catch (_) {
        continue;
      }
    }
    return versions;
  }

  static Map<String, dynamic> toJson(Advertisement ad) {
    return {
      'id': ad.id,
      'title': ad.title,
      'description': ad.description,
      'banner_url': ad.bannerUrl,
      'click_url': ad.clickUrl,
      'position': ad.position,
      'priority': ad.priority,
      'start_date': ad.startDate.toIso8601String().split('T')[0],
      'end_date': ad.endDate.toIso8601String().split('T')[0],
      'type': ad.type,
      'action': ad.action,
      'button_color': ad.buttonColor,
      'duration': ad.duration,
      if (ad.byLanguage.isNotEmpty)
        _byLanguageField: ad.byLanguage.map(
          (language, version) => MapEntry(language, toJson(version)),
        ),
    };
  }

  static int _parseDuration(dynamic value) {
    if (value is int) {
      return value.clamp(_minDurationSeconds, _maxDurationSeconds);
    }
    if (value is num) {
      return value.toInt().clamp(_minDurationSeconds, _maxDurationSeconds);
    }
    return _defaultDurationSeconds;
  }
}
