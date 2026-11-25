import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendPremiumServer;

/// One of a premium server's configs, as the engine listed it.
class PremiumServerConfigDto {
  const PremiumServerConfigDto({
    required this.id,
    required this.name,
    required this.url,
  });

  final int id;
  final String name;
  final String url;

  PremiumServerConfig toDomain() =>
      PremiumServerConfig(id: id, name: name, url: url);

  static const _fallbackName = 'Server';
}

/// One premium server, as the engine listed it.
class PremiumServerDto {
  const PremiumServerDto({
    required this.id,
    required this.name,
    required this.configs,
    this.icon,
  });

  final int id;
  final String name;
  final String? icon;
  final List<PremiumServerConfigDto> configs;

  /// Drops configs the app cannot dial, so a scheme the tunnel does not
  /// support never reaches the list the user taps.
  PremiumServer toDomain() {
    final dialable = configs
        .map((config) => config.toDomain())
        .where((config) => config.hasValidUrl)
        .toList();
    return PremiumServer(id: id, name: name, icon: icon, configs: dialable);
  }

  /// The servers an engine answer listed: unnamed ones named, undialable
  /// configs dropped, and servers left with none dropped.
  static List<PremiumServer> listFromBackend(
    List<BackendPremiumServer> servers,
  ) {
    return servers
        .map(
          (s) => PremiumServerDto(
            id: s.id,
            name: s.name ?? _fallbackName,
            icon: s.icon,
            configs: [
              for (final c in s.configs)
                PremiumServerConfigDto(
                  id: c.id,
                  name: c.name ?? PremiumServerConfigDto._fallbackName,
                  url: c.url,
                ),
            ],
          ).toDomain(),
        )
        .where((server) => server.configs.isNotEmpty)
        .toList();
  }

  static const _fallbackName = 'Server';
}
