import 'package:begzar/modules/settings/application/services/settings_service.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/settings_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_keyed_storage.dart';
import '../settings_test_doubles.dart';

({SettingsService service, MemoryKeyedStorage store}) _service({
  bool systemProxySupported = false,
}) {
  final store = MemoryKeyedStorage();
  return (
    service: SettingsService(
      SettingsRepository(
        storage: SettingsStorage(storage: store),
        systemProxySupported: systemProxySupported,
      ),
    ),
    store: store,
  );
}

void main() {
  group('changing a preference', () {
    test('returns the next value and writes it', () async {
      final harness = _service();
      final start = SettingsPreferences.initial(systemProxySupported: false);

      final next = await harness.service.changeDnsServer(
        start,
        rawValue: '1.1.1.1',
      );

      expect(next?.dnsServer, '1.1.1.1');
      expect(harness.store.values['settings_dns_server'], '1.1.1.1');
    });

    test(
      'a resolver the engine cannot query is refused, and nothing is written',
      () async {
        final harness = _service();
        final start = SettingsPreferences.initial(systemProxySupported: false);

        final next = await harness.service.changeDnsServer(
          start,
          rawValue: 'dns.google',
        );

        expect(next, isNull);
        expect(harness.store.values, isEmpty);
      },
    );

    test('leaves the other preferences as they were', () async {
      final harness = _service();
      final start = SettingsPreferences.initial(
        systemProxySupported: false,
      ).copyWith(dns: DnsServer.parse('1.1.1.1'), adsBlock: true);

      final next = await harness.service.changeAppExclude(start, enabled: true);

      expect(next.appExclude, isTrue);
      expect(next.adsBlock, isTrue);
      expect(next.dnsServer, '1.1.1.1');
    });
  });

  group('changeExposure', () {
    test('applies the domain rule and persists the whole exposure', () async {
      final harness = _service(systemProxySupported: true);
      final start = SettingsPreferences.initial(systemProxySupported: true);

      final next = await harness.service.changeExposure(
        start,
        (exposure) => exposure.withProxyOnly(true),
      );

      expect(next.exposure.proxyOnly, isTrue);
      expect(next.exposure.systemProxy, isFalse);
      expect(harness.store.values['settings_proxy_only'], 'true');
      expect(harness.store.values['settings_system_proxy'], 'false');
    });

    // Nothing to take over, so there is nothing to record either.
    test('a change the domain refuses is never written', () async {
      final harness = _service();
      final start = SettingsPreferences.initial(systemProxySupported: false);

      final next = await harness.service.changeExposure(
        start,
        (exposure) => exposure.withMode(ExposureMode.systemProxy),
      );

      expect(next.exposure, start.exposure);
      expect(harness.store.values, isEmpty);
    });
  });

  group('app routing', () {
    test('should write the mode under its stored name', () async {
      final harness = _service();

      final next = await harness.service.changeAppRoutingMode(
        AppRoutingSelection.initial,
        AppRoutingMode.onlySelected,
      );

      expect(next.mode, AppRoutingMode.onlySelected);
      expect(
        harness.store.values['settings_app_routing_mode'],
        'only_selected',
      );
    });

    test('should write a pick only to the list in force', () async {
      final harness = _service();
      const current = AppRoutingSelection(
        mode: AppRoutingMode.onlySelected,
        allExcept: {'a'},
      );

      final next = await harness.service.setAppPicked(
        current,
        'b',
        picked: true,
      );

      expect(next.onlySelected, {'b'});
      expect(next.allExcept, {'a'});
      expect(
        harness.store.values['settings_app_routing_only_selected'],
        contains('b'),
      );
      expect(
        harness.store.values.containsKey('settings_excluded_apps'),
        isFalse,
      );
    });

    test('should remove a pick from the list in force', () async {
      final harness = _service();
      const current = AppRoutingSelection(allExcept: {'a', 'b'});

      final next = await harness.service.setAppPicked(
        current,
        'a',
        picked: false,
      );

      expect(next.allExcept, {'b'});
      expect(
        harness.store.values['settings_excluded_apps'],
        isNot(contains('a')),
      );
    });

    test('should clear only the list in force', () async {
      final harness = _service();
      const current = AppRoutingSelection(
        mode: AppRoutingMode.onlySelected,
        allExcept: {'a'},
        onlySelected: {'b'},
      );
      await harness.service.setAppPicked(current, 'b', picked: true);
      await harness.service.setAppPicked(
        current.withMode(AppRoutingMode.allExcept),
        'a',
        picked: true,
      );

      final next = await harness.service.clearPickedApps(current);

      expect(next.onlySelected, isEmpty);
      expect(next.allExcept, {'a'});
      expect(
        harness.store.values.containsKey('settings_app_routing_only_selected'),
        isFalse,
      );
      expect(harness.store.values['settings_excluded_apps'], contains('a'));
    });

    test('should load the selection that was stored', () async {
      final harness = _service();
      await harness.service.changeAppRoutingMode(
        AppRoutingSelection.initial,
        AppRoutingMode.onlySelected,
      );

      final loaded = await harness.service.loadAppRouting();

      expect(loaded.mode, AppRoutingMode.onlySelected);
    });

    test('should keep picked apps in the list that is loaded', () async {
      final store = MemoryKeyedStorage();
      final service = SettingsService(
        SettingsRepository(
          storage: SettingsStorage(storage: store),
          systemProxySupported: false,
          // Nothing is installed, so a picked app can only come from the
          // picks.
          installedApps: const FakeInstalledApps([]),
        ),
      );

      final apps = await service.loadInstalledApps(picked: {'com.gone'});

      expect(apps.map((app) => app.packageName), ['com.gone']);
    }, skip: readsRunningPrograms ? desktopSkipReason : null);
  });
}
