enum RoutingAction { direct, block, proxy }

enum RoutingEntryType { domain, ip }

class CustomRoutingRules {
  final List<String> directDomains;
  final List<String> directIps;
  final List<String> blockDomains;
  final List<String> blockIps;
  final List<String> proxyDomains;
  final List<String> proxyIps;

  const CustomRoutingRules({
    this.directDomains = const [],
    this.directIps = const [],
    this.blockDomains = const [],
    this.blockIps = const [],
    this.proxyDomains = const [],
    this.proxyIps = const [],
  });

  static const empty = CustomRoutingRules();

  int get totalCount =>
      directDomains.length +
      directIps.length +
      blockDomains.length +
      blockIps.length +
      proxyDomains.length +
      proxyIps.length;

  List<String> domainsFor(RoutingAction action) => switch (action) {
    RoutingAction.direct => directDomains,
    RoutingAction.block => blockDomains,
    RoutingAction.proxy => proxyDomains,
  };

  List<String> ipsFor(RoutingAction action) => switch (action) {
    RoutingAction.direct => directIps,
    RoutingAction.block => blockIps,
    RoutingAction.proxy => proxyIps,
  };

  CustomRoutingRules copyWith({
    List<String>? directDomains,
    List<String>? directIps,
    List<String>? blockDomains,
    List<String>? blockIps,
    List<String>? proxyDomains,
    List<String>? proxyIps,
  }) {
    return CustomRoutingRules(
      directDomains: directDomains ?? this.directDomains,
      directIps: directIps ?? this.directIps,
      blockDomains: blockDomains ?? this.blockDomains,
      blockIps: blockIps ?? this.blockIps,
      proxyDomains: proxyDomains ?? this.proxyDomains,
      proxyIps: proxyIps ?? this.proxyIps,
    );
  }

  /// Normalizes user input for xray routing rules.
  static String? normalizeEntry({
    required String raw,
    required RoutingEntryType type,
  }) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    if (type == RoutingEntryType.ip) {
      return _isValidIpOrCidr(value) ? value : null;
    }

    if (value.startsWith('domain:') ||
        value.startsWith('full:') ||
        value.startsWith('regexp:') ||
        value.startsWith('keyword:')) {
      return value;
    }

    final host = value.replaceAll(RegExp(r'^https?://'), '').split('/').first;
    if (host.isEmpty || host.contains(' ')) return null;
    return 'domain:$host';
  }

  static bool _isValidIpOrCidr(String value) {
    if (value.contains('/')) {
      final parts = value.split('/');
      if (parts.length != 2) return false;
      final prefix = int.tryParse(parts[1]);
      if (prefix == null) return false;
      return _isValidIp(parts[0]) && prefix >= 0 && prefix <= 128;
    }
    return _isValidIp(value);
  }

  static bool _isValidIp(String value) {
    final v4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (v4.hasMatch(value)) {
      return value.split('.').every((part) {
        final n = int.tryParse(part);
        return n != null && n >= 0 && n <= 255;
      });
    }

    return value.contains(':');
  }
}
