import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';

/// One dialable endpoint on a [PremiumServer].
///
/// Parsing lives in `data/dtos/premium_server_dto.dart`; this side knows
/// nothing about the API's JSON keys.
class PremiumServerConfig {
  final int id;
  final String name;
  final String url;

  const PremiumServerConfig({
    required this.id,
    required this.name,
    required this.url,
  });

  /// Two letters the name opens with, lowercased for the flag asset.
  /// `"FI-01 - ALL NEW"` is `fi`; a name without that prefix is null.
  String? get flagCode {
    final match = _flagPrefix.firstMatch(name.trim());
    return match?.group(1)?.toLowerCase();
  }

  static final _flagPrefix = RegExp(r'^([A-Za-z]{2})(?=[-_\s]|$)');

  /// The tunnel takes a [ProxyConfigEntity], and the country prefix is what
  /// tells two identically-named configs apart in the connection card.
  ProxyConfigEntity toProxyConfig({String? countryName}) {
    final label = countryName == null || countryName.isEmpty
        ? name
        : '$countryName · $name';
    return ProxyConfigEntity(url: url, name: label);
  }

  /// Whether the engine can dial this config, by the same list a manual
  /// connect checks, so nothing is listed that a tap would then refuse.
  bool get hasValidUrl =>
      ProxyConfigValidator.supportedSchemes.any(url.startsWith);
}

/// A country or location grouping several configs, as the premium list shows.
class PremiumServer {
  final int id;
  final String name;
  final String? icon;
  final List<PremiumServerConfig> configs;

  const PremiumServer({
    required this.id,
    required this.name,
    this.icon,
    this.configs = const [],
  });

  /// Flag for the list card: the first config's country prefix. The API also
  /// sends an `icon` URL; the app does not fetch it.
  String? get flagCode => configs.isEmpty ? null : configs.first.flagCode;
}
