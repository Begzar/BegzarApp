import 'package:begzar/modules/settings/application/services/routing_rules_service.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_keyed_storage.dart';

({RoutingRulesService service, MemoryKeyedStorage store}) _service() {
  final store = MemoryKeyedStorage();
  return (
    service: RoutingRulesService(
      SettingsRepository(
        storage: SettingsStorage(storage: store),
        systemProxySupported: false,
      ),
    ),
    store: store,
  );
}

void main() {
  group('addRule', () {
    test('normalizes a bare host into a domain rule', () async {
      final added = await _service().service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.direct,
        type: RoutingEntryType.domain,
        rawValue: '  HTTPS://Example.com/path  ',
      );

      expect(added.outcome, RoutingRuleOutcome.added);
      expect(added.rules.directDomains, ['domain:example.com']);
    });

    test('keeps an entry that already names its match type', () async {
      final added = await _service().service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.block,
        type: RoutingEntryType.domain,
        rawValue: 'keyword:ads',
      );

      expect(added.rules.blockDomains, ['keyword:ads']);
    });

    test('an entry the engine cannot route on is refused', () async {
      final rejected = await _service().service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.direct,
        type: RoutingEntryType.ip,
        rawValue: 'not-an-address',
      );

      expect(rejected.outcome, RoutingRuleOutcome.rejected);
      expect(rejected.outcome.isAccepted, isFalse);
      expect(rejected.rules.totalCount, 0);
    });

    // Asking for a rule that is already in force is not a failure, but it is
    // not an edit either — the screen says something different for each.
    test('a duplicate is reported apart from a rejection', () async {
      final service = _service().service;
      final first = await service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.proxy,
        type: RoutingEntryType.domain,
        rawValue: 'example.com',
      );

      final second = await service.addRule(
        first.rules,
        action: RoutingAction.proxy,
        type: RoutingEntryType.domain,
        rawValue: 'EXAMPLE.com',
      );

      expect(second.outcome, RoutingRuleOutcome.alreadyPresent);
      expect(second.outcome.isAccepted, isTrue);
      expect(second.rules.proxyDomains, ['domain:example.com']);
    });

    test('an added rule reaches storage', () async {
      final harness = _service();

      await harness.service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.block,
        type: RoutingEntryType.ip,
        rawValue: '10.0.0.0/8',
      );

      expect(
        harness.store.values['settings_custom_routing'],
        contains('10.0.0.0/8'),
      );
    });

    test('an action keeps its domains and addresses apart', () async {
      final service = _service().service;
      final withDomain = await service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.direct,
        type: RoutingEntryType.domain,
        rawValue: 'example.com',
      );

      final withIp = await service.addRule(
        withDomain.rules,
        action: RoutingAction.direct,
        type: RoutingEntryType.ip,
        rawValue: '10.0.0.1',
      );

      expect(withIp.rules.directDomains, ['domain:example.com']);
      expect(withIp.rules.directIps, ['10.0.0.1']);
    });

    test('adding to one action leaves the others alone', () async {
      final service = _service().service;
      final blocked = await service.addRule(
        CustomRoutingRules.empty,
        action: RoutingAction.block,
        type: RoutingEntryType.domain,
        rawValue: 'ads.example.com',
      );

      final direct = await service.addRule(
        blocked.rules,
        action: RoutingAction.direct,
        type: RoutingEntryType.domain,
        rawValue: 'bank.example.com',
      );

      expect(direct.rules.blockDomains, ['domain:ads.example.com']);
      expect(direct.rules.directDomains, ['domain:bank.example.com']);
    });
  });

  test('removeRule drops only the named entry', () async {
    final service = _service().service;

    final next = await service.removeRule(
      const CustomRoutingRules(
        directDomains: ['domain:a.com', 'domain:b.com'],
        directIps: ['10.0.0.1'],
      ),
      action: RoutingAction.direct,
      type: RoutingEntryType.domain,
      value: 'domain:a.com',
    );

    expect(next.directDomains, ['domain:b.com']);
    expect(next.directIps, ['10.0.0.1']);
  });

  test('clearAction empties one action, not the rule set', () async {
    final service = _service().service;

    final next = await service.clearAction(
      const CustomRoutingRules(
        directDomains: ['domain:a.com'],
        directIps: ['10.0.0.1'],
        blockDomains: ['domain:ads.com'],
      ),
      RoutingAction.direct,
    );

    expect(next.directDomains, isEmpty);
    expect(next.directIps, isEmpty);
    expect(next.blockDomains, ['domain:ads.com']);
  });
}
