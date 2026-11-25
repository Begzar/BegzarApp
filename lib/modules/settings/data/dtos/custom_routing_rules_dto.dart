import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';

/// Stored shape of [CustomRoutingRules].
///
/// Six parallel lists of already-normalized entries. Reading is deliberately
/// forgiving: a list that is missing, is not a list, or holds anything other
/// than non-empty strings degrades to an empty list rather than failing the
/// whole record, because one corrupted key must not cost the user every rule
/// they entered.
abstract final class CustomRoutingRulesDto {
  static Map<String, dynamic> toJson(CustomRoutingRules rules) => {
    directDomainsField: rules.directDomains,
    directIpsField: rules.directIps,
    blockDomainsField: rules.blockDomains,
    blockIpsField: rules.blockIps,
    proxyDomainsField: rules.proxyDomains,
    proxyIpsField: rules.proxyIps,
  };

  static CustomRoutingRules fromJson(Map<String, dynamic> json) {
    return CustomRoutingRules(
      directDomains: _readList(json, directDomainsField),
      directIps: _readList(json, directIpsField),
      blockDomains: _readList(json, blockDomainsField),
      blockIps: _readList(json, blockIpsField),
      proxyDomains: _readList(json, proxyDomainsField),
      proxyIps: _readList(json, proxyIpsField),
    );
  }

  static List<String> _readList(Map<String, dynamic> json, String field) {
    final raw = json[field];
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static const directDomainsField = 'directDomains';
  static const directIpsField = 'directIps';
  static const blockDomainsField = 'blockDomains';
  static const blockIpsField = 'blockIps';
  static const proxyDomainsField = 'proxyDomains';
  static const proxyIpsField = 'proxyIps';
}
