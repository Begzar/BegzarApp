import 'package:begzar/modules/settings/application/services/routing_rules_service.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The custom routing rules the screen edits.
class CustomRoutingNotifier extends Notifier<CustomRoutingRules> {
  late RoutingRulesService _service;
  bool _userTouched = false;
  late Future<void> _loadFuture;

  @override
  CustomRoutingRules build() {
    _service = ref.watch(routingRulesServiceProvider);
    _loadFuture = _loadRules();
    return CustomRoutingRules.empty;
  }

  Future<void> ensureLoaded() => _loadFuture;

  Future<void> _loadRules() async {
    final stored = await _service.load();
    if (!ref.mounted || _userTouched) return;
    state = stored;
  }

  /// Reports which of the three things happened, so the sheet can close on a
  /// new rule and say something useful about the other two.
  Future<RoutingRuleOutcome> addRule({
    required RoutingAction action,
    required RoutingEntryType type,
    required String rawValue,
  }) async {
    await ensureLoaded();
    final result = await _service.addRule(
      state,
      action: action,
      type: type,
      rawValue: rawValue,
    );
    // Only a real edit claims the state: an entry the engine cannot route on
    // must not stop a slow read from publishing the stored rules.
    if (result.outcome == RoutingRuleOutcome.added) {
      _userTouched = true;
      state = result.rules;
    }
    return result.outcome;
  }

  Future<void> removeRule({
    required RoutingAction action,
    required RoutingEntryType type,
    required String value,
  }) async {
    await _touch();
    state = await _service.removeRule(
      state,
      action: action,
      type: type,
      value: value,
    );
  }

  Future<void> clearAction(RoutingAction action) async {
    await _touch();
    state = await _service.clearAction(state, action);
  }

  /// Waits for the stored rules to land, then claims the state for the user,
  /// so a slow read cannot overwrite an edit made in the meantime.
  Future<void> _touch() async {
    await ensureLoaded();
    _userTouched = true;
  }
}

final customRoutingProvider =
    NotifierProvider<CustomRoutingNotifier, CustomRoutingRules>(
      CustomRoutingNotifier.new,
    );
