import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';

/// What happened to a rule the user tried to add.
enum RoutingRuleOutcome {
  /// Added, and the rule set now includes it.
  added,

  /// The entry was already in that action's list, so nothing changed. Not a
  /// failure: the user asked for a rule that is already in force.
  alreadyPresent,

  /// The entry is not a domain or an address this engine can route on.
  rejected;

  bool get isAccepted => this != rejected;
}

/// The rule set the engine is handed, and the edits the routing screen makes
/// to it.
///
/// Adding is the part worth having out of the notifier: the raw text has to
/// be normalized before anything else can be decided about it, an entry the
/// engine cannot route on has to be refused, and a duplicate has to be told
/// apart from a rejection so the screen can say something different.
class RoutingRulesService {
  const RoutingRulesService(this._repository);

  final SettingsRepository _repository;

  Future<CustomRoutingRules> load() => _repository.readRoutingRules();

  Future<({RoutingRuleOutcome outcome, CustomRoutingRules rules})> addRule(
    CustomRoutingRules current, {
    required RoutingAction action,
    required RoutingEntryType type,
    required String rawValue,
  }) async {
    final normalized = CustomRoutingRules.normalizeEntry(
      raw: rawValue,
      type: type,
    );
    if (normalized == null) {
      return (outcome: RoutingRuleOutcome.rejected, rules: current);
    }

    final existing = _entriesOf(current, action: action, type: type);
    if (existing.contains(normalized)) {
      return (outcome: RoutingRuleOutcome.alreadyPresent, rules: current);
    }

    final next = _replaceEntries(
      current,
      action: action,
      type: type,
      entries: [...existing, normalized],
    );
    await _repository.writeRoutingRules(next);
    return (outcome: RoutingRuleOutcome.added, rules: next);
  }

  Future<CustomRoutingRules> removeRule(
    CustomRoutingRules current, {
    required RoutingAction action,
    required RoutingEntryType type,
    required String value,
  }) async {
    final next = _replaceEntries(
      current,
      action: action,
      type: type,
      entries: _entriesOf(
        current,
        action: action,
        type: type,
      ).where((entry) => entry != value).toList(),
    );
    await _repository.writeRoutingRules(next);
    return next;
  }

  Future<CustomRoutingRules> clearAction(
    CustomRoutingRules current,
    RoutingAction action,
  ) async {
    final next = switch (action) {
      RoutingAction.direct => current.copyWith(
        directDomains: const [],
        directIps: const [],
      ),
      RoutingAction.block => current.copyWith(
        blockDomains: const [],
        blockIps: const [],
      ),
      RoutingAction.proxy => current.copyWith(
        proxyDomains: const [],
        proxyIps: const [],
      ),
    };
    await _repository.writeRoutingRules(next);
    return next;
  }

  List<String> _entriesOf(
    CustomRoutingRules rules, {
    required RoutingAction action,
    required RoutingEntryType type,
  }) {
    return type == RoutingEntryType.domain
        ? rules.domainsFor(action)
        : rules.ipsFor(action);
  }

  CustomRoutingRules _replaceEntries(
    CustomRoutingRules rules, {
    required RoutingAction action,
    required RoutingEntryType type,
    required List<String> entries,
  }) {
    final domains = type == RoutingEntryType.domain
        ? entries
        : rules.domainsFor(action);
    final ips = type == RoutingEntryType.ip ? entries : rules.ipsFor(action);

    return switch (action) {
      RoutingAction.direct => rules.copyWith(
        directDomains: domains,
        directIps: ips,
      ),
      RoutingAction.block => rules.copyWith(
        blockDomains: domains,
        blockIps: ips,
      ),
      RoutingAction.proxy => rules.copyWith(
        proxyDomains: domains,
        proxyIps: ips,
      ),
    };
  }
}
