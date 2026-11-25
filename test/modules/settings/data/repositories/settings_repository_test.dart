import 'dart:convert';

import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/data/repositories/settings_repository.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/memory_keyed_storage.dart';
import '../../settings_test_doubles.dart';

const _ownPackageName = 'cloud.begzar.begzar';

Future<String> _readOwnPackage() async => _ownPackageName;

SettingsRepository _repositoryWithApps({
  required List<String> packages,
  required Future<String> Function() ownPackage,
}) {
  return SettingsRepository(
    storage: SettingsStorage(storage: MemoryKeyedStorage()),
    systemProxySupported: false,
    installedApps: FakeInstalledApps(packages),
    ownPackage: ownPackage,
  );
}

SettingsRepository _repository(
  MemoryKeyedStorage store, {
  bool systemProxySupported = false,
  Future<String> Function() ownPackage = _readOwnPackage,
}) {
  return SettingsRepository(
    storage: SettingsStorage(storage: store),
    systemProxySupported: systemProxySupported,
    ownPackage: ownPackage,
  );
}

SettingsRepository _brokenRepository({bool systemProxySupported = false}) {
  return SettingsRepository(
    storage: SettingsStorage(storage: const FailingKeyedStorage()),
    systemProxySupported: systemProxySupported,
  );
}

void main() {
  group('readPreferences', () {
    test('an empty store reads as the platform default', () async {
      final preferences = await _repository(
        MemoryKeyedStorage(),
      ).readPreferences();

      expect(preferences.adsBlock, isFalse);
      expect(preferences.appExclude, isFalse);
      expect(preferences.dns, DnsServer.fallback);
      expect(preferences.exposure.proxyOnly, isFalse);
      expect(preferences.exposure.systemProxy, isFalse);
    });

    test('reads back what a previous launch wrote', () async {
      final store = MemoryKeyedStorage({
        'settings_ads_block': 'true',
        'settings_app_exclude': 'true',
        'settings_dns_server': '1.1.1.1',
        'settings_proxy_only': 'true',
        'settings_bypass_lan': 'true',
      });

      final preferences = await _repository(store).readPreferences();

      expect(preferences.adsBlock, isTrue);
      expect(preferences.appExclude, isTrue);
      expect(preferences.dnsServer, '1.1.1.1');
      expect(preferences.exposure.proxyOnly, isTrue);
      expect(preferences.exposure.sharesWithLan, isTrue);
    });

    // Builds before the check on the way in accepted anything non-empty, so
    // a resolver that can never answer may already be on disk.
    test('a stored value that is not an address falls back', () async {
      final store = MemoryKeyedStorage({'settings_dns_server': 'hello'});

      final preferences = await _repository(store).readPreferences();

      expect(preferences.dns, DnsServer.fallback);
    });

    // A locked keychain must leave the user with a usable screen rather than
    // an exception on the way to it. On Windows that is the system proxy,
    // not the tunnel an empty store gives: a store that cannot answer has
    // not said the user never chose, and the tunnel costs an admin prompt.
    test('storage that cannot be read falls back to the defaults', () async {
      final preferences = await _brokenRepository(
        systemProxySupported: true,
      ).readPreferences();

      expect(preferences.dns, DnsServer.fallback);
      expect(preferences.exposure.systemProxy, isTrue);
    });

    test('should read a stored tunnel', () async {
      final store = MemoryKeyedStorage({
        'settings_tunnel_mode': 'true',
        'settings_proxy_only': 'false',
        'settings_system_proxy': 'false',
      });

      final preferences = await _repository(
        store,
        systemProxySupported: true,
      ).readPreferences();

      expect(preferences.exposure.mode, ExposureMode.tunnel);
    });

    test(
      'should read the tunnel on Windows from a store never written',
      () async {
        final preferences = await _repository(
          MemoryKeyedStorage(),
          systemProxySupported: true,
        ).readPreferences();

        expect(preferences.exposure.mode, ExposureMode.tunnel);
      },
    );
  });

  group('Experimental settings', () {
    test('are off, in MASQUE, until something is stored', () async {
      final preferences = await _repository(
        MemoryKeyedStorage(),
      ).readPreferences();

      expect(preferences.experimental, isFalse);
      expect(preferences.warpMode, WarpMode.masque);
    });

    test('read back what a previous launch wrote', () async {
      final store = MemoryKeyedStorage();
      await _repository(store).writeExperimental(true);
      await _repository(store).writeWarpMode(WarpMode.gool);

      expect(store.values['settings_experimental'], 'true');
      expect(store.values['settings_warp_mode'], 'gool');
      final preferences = await _repository(store).readPreferences();
      expect(preferences.experimental, isTrue);
      expect(preferences.warpMode, WarpMode.gool);
    });

    test('a mode this build does not know reads as MASQUE', () async {
      final preferences = await _repository(
        MemoryKeyedStorage({'settings_warp_mode': 'teleport'}),
      ).readPreferences();

      expect(preferences.warpMode, WarpMode.masque);
    });

    test('a store that will not answer leaves them off', () async {
      final repository = _brokenRepository();
      await repository.writeExperimental(true);

      expect((await repository.readPreferences()).experimental, isFalse);
    });
  });

  group('writeProxyExposure', () {
    test('writes every flag, not just the one that changed', () async {
      final store = MemoryKeyedStorage();
      final exposure = ProxyExposure.initial(
        systemProxySupported: true,
      ).withProxyOnly(true);

      await _repository(store, systemProxySupported: true) //
          .writeProxyExposure(exposure);

      expect(store.values['settings_proxy_only'], 'true');
      expect(store.values['settings_system_proxy'], 'false');
      expect(store.values['settings_bypass_lan'], 'false');
    });

    test('leaves the system proxy key alone where there is none', () async {
      final store = MemoryKeyedStorage();
      final exposure = ProxyExposure.initial(
        systemProxySupported: false,
      ).withProxyOnly(true);

      await _repository(store).writeProxyExposure(exposure);

      expect(store.values['settings_proxy_only'], 'true');
      expect(store.values.containsKey('settings_system_proxy'), isFalse);
    });

    test('should write the tunnel flag on Windows', () async {
      final store = MemoryKeyedStorage();
      final exposure = ProxyExposure.initial(
        systemProxySupported: true,
      ).withMode(ExposureMode.tunnel);

      await _repository(store, systemProxySupported: true) //
          .writeProxyExposure(exposure);

      expect(store.values['settings_tunnel_mode'], 'true');
      expect(store.values['settings_proxy_only'], 'false');
      expect(store.values['settings_system_proxy'], 'false');
    });

    test('should clear the tunnel flag when another mode is chosen', () async {
      for (final mode in [ExposureMode.systemProxy, ExposureMode.proxyOnly]) {
        final store = MemoryKeyedStorage({
          'settings_tunnel_mode': 'true',
          'settings_proxy_only': 'false',
          'settings_system_proxy': 'false',
        });
        final repository = _repository(store, systemProxySupported: true);
        final stored = await repository.readPreferences();

        await repository.writeProxyExposure(stored.exposure.withMode(mode));
        final readBack = await repository.readPreferences();

        expect(store.values['settings_tunnel_mode'], 'false', reason: '$mode');
        expect(readBack.exposure.mode, mode);
      }
    });

    test(
      'should leave the tunnel key alone where there is no system proxy',
      () async {
        final store = MemoryKeyedStorage();
        final exposure = ProxyExposure.initial(systemProxySupported: false);

        await _repository(store).writeProxyExposure(exposure);

        expect(store.values.containsKey('settings_tunnel_mode'), isFalse);
      },
    );

    test('a write that fails is not an error the caller has to handle', () {
      final exposure = ProxyExposure.initial(systemProxySupported: false);

      expect(_brokenRepository().writeProxyExposure(exposure), completes);
    });
  });

  group('readAppRouting', () {
    test(
      'should load an existing excluded list as the all-except list',
      () async {
        final store = MemoryKeyedStorage({
          'settings_excluded_apps': jsonEncode(['com.a']),
        });

        final selection = await _repository(store).readAppRouting();

        expect(selection.mode, AppRoutingMode.allExcept);
        expect(selection.allExcept, {'com.a'});
        expect(selection.onlySelected, isEmpty);
      },
    );

    test(
      'should move a list stored under the legacy key to the current key',
      () async {
        final store = MemoryKeyedStorage({
          'excluded_apps': jsonEncode(['com.old']),
        });

        final selection = await _repository(store).readAppRouting();

        expect(selection.allExcept, {'com.old'});
        expect(selection.onlySelected, isEmpty);
        expect(store.values['settings_excluded_apps'], jsonEncode(['com.old']));
      },
    );

    // The move is a side effect of the read, so its failure must not cost the
    // list the read already holds; the legacy key stays for the next try.
    test(
      'should keep a legacy list when moving it to the current key fails',
      () async {
        final store = WriteFailingKeyedStorage({
          'excluded_apps': jsonEncode(['com.old']),
        });

        final selection = await _repository(store).readAppRouting();

        expect(selection.allExcept, {'com.old'});
        expect(store.values['excluded_apps'], jsonEncode(['com.old']));
      },
    );

    // The legacy list is copied to the current key on the first read and stays
    // where it was, so clearing the current key alone would bring it back.
    test('should not bring a cleared legacy list back', () async {
      final store = MemoryKeyedStorage({
        'excluded_apps': jsonEncode(['com.old']),
      });
      final repository = _repository(store);
      await repository.readAppRouting();

      await repository.writePickedApps(AppRoutingMode.allExcept, {});
      final selection = await repository.readAppRouting();

      expect(selection.allExcept, isEmpty);
      expect(store.values.containsKey('excluded_apps'), isFalse);
    });

    // A user who toggled Begzar in the old picker still has it stored, and a
    // list that kept it would show a row Begzar cannot honor.
    test('should leave the own package out of both stored lists', () async {
      final store = MemoryKeyedStorage({
        'settings_excluded_apps': jsonEncode([_ownPackageName, 'com.a']),
        'settings_app_routing_only_selected': jsonEncode([
          'com.b',
          _ownPackageName,
        ]),
      });

      final selection = await _repository(store).readAppRouting();

      expect(selection.allExcept, {'com.a'});
      expect(selection.onlySelected, {'com.b'});
    });

    test(
      'should keep both stored lists when the own package is unknown',
      () async {
        final store = MemoryKeyedStorage({
          'settings_excluded_apps': jsonEncode(['com.a']),
          'settings_app_routing_only_selected': jsonEncode(['com.b']),
        });
        final repository = _repository(
          store,
          ownPackage: () async => throw StateError('no package info'),
        );

        final selection = await repository.readAppRouting();

        expect(selection.allExcept, {'com.a'});
        expect(selection.onlySelected, {'com.b'});
      },
    );

    test('should read a stored mode it does not know as all-except', () async {
      final store = MemoryKeyedStorage({
        'settings_app_routing_mode': 'sideways',
      });

      final selection = await _repository(store).readAppRouting();

      expect(selection.mode, AppRoutingMode.allExcept);
    });

    test(
      'should read back the mode and both lists that were written',
      () async {
        final store = MemoryKeyedStorage();
        final repository = _repository(store);
        await repository.writePickedApps(AppRoutingMode.allExcept, {'com.a'});
        await repository.writePickedApps(AppRoutingMode.onlySelected, {
          'com.b',
        });
        await repository.writeAppRoutingMode(AppRoutingMode.onlySelected);

        final selection = await repository.readAppRouting();

        expect(selection.mode, AppRoutingMode.onlySelected);
        expect(selection.allExcept, {'com.a'});
        expect(selection.onlySelected, {'com.b'});
      },
    );

    test(
      'should fall back to the initial selection when storage throws',
      () async {
        final selection = await _brokenRepository().readAppRouting();

        expect(selection, same(AppRoutingSelection.initial));
      },
    );
  });

  group('writePickedApps', () {
    test('should delete the key of a mode whose set is empty', () async {
      final store = MemoryKeyedStorage();
      final repository = _repository(store);
      await repository.writePickedApps(AppRoutingMode.onlySelected, {'com.b'});

      await repository.writePickedApps(AppRoutingMode.onlySelected, {});

      expect(
        store.values.containsKey('settings_app_routing_only_selected'),
        isFalse,
      );
    });

    test('should not complete with an error when storage throws', () {
      expect(
        _brokenRepository().writePickedApps(AppRoutingMode.allExcept, {'a'}),
        completes,
      );
    });
  });

  group('readInstalledApps', () {
    test("should leave out the app's own package", () async {
      final repository = _repositoryWithApps(
        packages: ['cloud.begzar.begzar', 'com.a'],
        ownPackage: () async => 'cloud.begzar.begzar',
      );

      final apps = await repository.readInstalledApps();

      expect(apps.map((app) => app.packageName), ['com.a']);
    });

    test('should keep the list when the own package cannot be read', () async {
      final repository = _repositoryWithApps(
        packages: ['com.b', 'com.a'],
        ownPackage: () async => throw StateError('no package info'),
      );

      final apps = await repository.readInstalledApps();

      expect(apps.map((app) => app.packageName), ['com.a', 'com.b']);
    });
  }, skip: readsRunningPrograms ? desktopSkipReason : null);

  group('routing rules', () {
    test('a record survives a write and read', () async {
      final store = MemoryKeyedStorage();
      final repository = _repository(store);

      await repository.writeRoutingRules(
        const CustomRoutingRules(
          directDomains: ['domain:example.com'],
          blockIps: ['10.0.0.1'],
        ),
      );

      final rules = await repository.readRoutingRules();
      expect(rules.directDomains, ['domain:example.com']);
      expect(rules.blockIps, ['10.0.0.1']);
    });

    test('a corrupted record reads as no rules', () async {
      final store = MemoryKeyedStorage({
        'settings_custom_routing': 'not json at all',
      });

      final rules = await _repository(store).readRoutingRules();

      expect(rules.totalCount, 0);
    });

    test(
      'a record that is valid JSON but not a map reads as no rules',
      () async {
        final store = MemoryKeyedStorage({
          'settings_custom_routing': jsonEncode(['domain:example.com']),
        });

        final rules = await _repository(store).readRoutingRules();

        expect(rules.totalCount, 0);
      },
    );
  });
}
