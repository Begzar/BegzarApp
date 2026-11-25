import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendExitReading;

/// Reads an [IpInfo] out of whichever geo provider answered.
///
/// Seven sources are tried in turn and no two agree on field names, so every
/// read accepts the alternatives and falls back rather than throwing: a
/// half-readable answer still puts a country on the screen.
abstract final class IpInfoDto {
  static const String _unknownValue = 'Unknown';

  /// Country shown when the provider names none. Neutral rather than blank so
  /// the flag slot still renders something.
  static const String _fallbackCountryCode = 'US';

  /// The shape most third-party providers use, with `country_name` as
  /// ipapi.co's name for the country. `query` is nobody's in the current list —
  /// it was ip-api.com's name for the address, and is kept because reading one
  /// more spelling costs nothing and the list has changed before.
  static IpInfo fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['ip'] ?? json['query'] ?? _unknownValue,
      country: json['country'] ?? json['country_name'] ?? _unknownValue,
      countryCode:
          json['countryCode'] ?? json['country_code'] ?? _fallbackCountryCode,
    );
  }

  /// Begzar's own reading, as the engine read it.
  static IpInfo fromBegzar(BackendExitReading reading) {
    return IpInfo(
      ip: reading.ip ?? _unknownValue,
      country: reading.country ?? _unknownValue,
      countryCode: reading.countryCode ?? _fallbackCountryCode,
    );
  }
}
