import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';

/// Whether a config is well-formed enough to hand to the proxy engine.
///
/// This is a policy, not a repository. It performs no IO, stores nothing, and
/// its answer depends only on its argument, so it belongs in the domain rather
/// than behind a data-layer port.
abstract final class ProxyConfigValidator {
  /// Schemes the engine dials, and so the ones a config may carry.
  ///
  /// This is the one list both a manual connect and the premium list check, so
  /// a config is never shown and then refused when picked. It follows the
  /// share-link schemes in `begzar-engine/src/proxyurl/sharelink.go`; the first
  /// hysteria version is left out because the engine cannot dial it.
  static const supportedSchemes = <String>[
    'vless://',
    'vmess://',
    'ss://',
    'trojan://',
    'hysteria2://',
    'hy2://',
  ];

  /// True when [config] is named and carries a scheme the engine can dial.
  static bool isDialable(ProxyConfigEntity config) {
    if (config.url.isEmpty || config.name.isEmpty) return false;
    return supportedSchemes.any(config.url.startsWith);
  }
}
