import 'package:begzar/modules/settings/data/dtos/custom_routing_rules_dto.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomRoutingRulesDto.fromJson', () {
    test('reads every action into its own lists', () {
      final rules = CustomRoutingRulesDto.fromJson({
        'directDomains': ['domain:example.com'],
        'directIps': ['10.0.0.1'],
        'blockDomains': ['domain:ads.example.com'],
        'blockIps': ['10.0.0.2'],
        'proxyDomains': ['domain:proxied.example.com'],
        'proxyIps': ['10.0.0.3'],
      });

      expect(rules.directDomains, ['domain:example.com']);
      expect(rules.directIps, ['10.0.0.1']);
      expect(rules.blockDomains, ['domain:ads.example.com']);
      expect(rules.blockIps, ['10.0.0.2']);
      expect(rules.proxyDomains, ['domain:proxied.example.com']);
      expect(rules.proxyIps, ['10.0.0.3']);
    });

    test('a missing key reads as no rules for that action', () {
      final rules = CustomRoutingRulesDto.fromJson({
        'directDomains': ['domain:example.com'],
      });

      expect(rules.directDomains, ['domain:example.com']);
      expect(rules.blockDomains, isEmpty);
      expect(rules.proxyIps, isEmpty);
    });

    // One corrupted key must not cost the user the rules stored under the
    // others, so a bad value degrades to an empty list rather than throwing.
    test('a key holding something other than a list degrades to empty', () {
      final rules = CustomRoutingRulesDto.fromJson({
        'directDomains': 'domain:example.com',
        'directIps': 42,
        'blockDomains': ['domain:kept.example.com'],
      });

      expect(rules.directDomains, isEmpty);
      expect(rules.directIps, isEmpty);
      expect(rules.blockDomains, ['domain:kept.example.com']);
    });

    test('drops non-string and blank entries, and trims the rest', () {
      final rules = CustomRoutingRulesDto.fromJson({
        'directDomains': ['  domain:example.com  ', '', '   ', 7, null],
      });

      expect(rules.directDomains, ['domain:example.com']);
    });
  });

  test('a record survives a write and read unchanged', () {
    const original = CustomRoutingRules(
      directDomains: ['domain:example.com'],
      directIps: ['10.0.0.1'],
      blockDomains: ['domain:ads.example.com'],
      blockIps: ['192.168.0.0/16'],
      proxyDomains: ['keyword:video'],
      proxyIps: ['2001:db8::1'],
    );

    final restored = CustomRoutingRulesDto.fromJson(
      CustomRoutingRulesDto.toJson(original),
    );

    expect(restored.directDomains, original.directDomains);
    expect(restored.directIps, original.directIps);
    expect(restored.blockDomains, original.blockDomains);
    expect(restored.blockIps, original.blockIps);
    expect(restored.proxyDomains, original.proxyDomains);
    expect(restored.proxyIps, original.proxyIps);
  });
}
