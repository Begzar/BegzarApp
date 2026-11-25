import 'dart:io';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/modules/connection/data/repositories/connection_repository.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/tunnel_mode.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:begzar_engine/begzar_engine.dart';

import '../../connection_test_doubles.dart';

/// Windows and Linux always start the local proxy, and Apple always starts the
/// tunnel; only Android chooses by the options, which a test cannot be run on.
/// So each start can only be reached from the hosts that take it.
final _startsProxy = Platform.isWindows || Platform.isLinux;

const _vpnSkipReason = 'Windows and Linux start the proxy, not the tunnel.';

const _proxySkipReason = 'Apple starts the tunnel, never the proxy.';

const _onlyThroughComA = AppRouting(
  mode: AppRoutingMode.onlySelected,
  apps: ['com.a'],
);

const _onlyThroughBrowser = AppRouting(
  mode: AppRoutingMode.onlySelected,
  apps: ['My Browser.exe'],
);

/// Options that ask for the tunnel rather than either proxy mode.
final _tunnelOptions = testTunnelOptions(appRouting: _onlyThroughBrowser);

/// The channel `WindowsSystemProxyService` sets and clears the system proxy
/// through. It only calls it on Windows.
const _systemProxyChannel = MethodChannel('begzar/system_proxy');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionRepository.connect', () {
    test(
      'should return a VpnPermissionFailure when the start is refused permission',
      () async {
        // Quick connect probes beside the tunnel, so a refused VPN permission
        // no longer surfaces while testing — the dial is the first thing to
        // ask for it, and must say so in a type rather than in prose.
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(
            startFailure: const VpnPermissionFailure(
              'VPN permission denied: NEVPNErrorDomain error 5',
            ),
          ),
        );

        final result = await repository.connect(
          dialableConfig('a'),
          testTunnelOptions(),
        );

        final failure = result.getLeft().toNullable();
        expect(failure, isA<VpnPermissionFailure>());
        expect(failure?.userFacingKey, UserFacingErrorKeys.accessDenied);
      },
    );

    test('should wrap any other start failure as a TunnelFailure', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(
          startFailure: Exception('Failed to start VPN mode: engine exited'),
        ),
      );

      final result = await repository.connect(
        dialableConfig('a'),
        testTunnelOptions(),
      );

      expect(result.getLeft().toNullable(), isA<TunnelFailure>());
    });

    test('should hand the app routing to a VPN start', () async {
      final adapter = FakeProxyCoreAdapter(
        startFailure: Exception('Failed to start VPN mode: engine exited'),
      );

      await ConnectionRepository(adapter).connect(
        dialableConfig('a'),
        testTunnelOptions(appRouting: _onlyThroughComA),
      );

      expect(adapter.lastAppRouting, _onlyThroughComA);
    }, skip: _startsProxy ? _vpnSkipReason : null);

    test('should hand the app routing to a proxy start', () async {
      final adapter = FakeProxyCoreAdapter(
        startFailure: Exception('Failed to start Proxy mode: engine exited'),
      );

      await ConnectionRepository(adapter).connect(
        dialableConfig('a'),
        testTunnelOptions(appRouting: _onlyThroughComA),
      );

      expect(adapter.lastAppRouting, _onlyThroughComA);
    }, skip: _startsProxy ? null : _proxySkipReason);
  });

  group('in a build without the engine', () {
    test('should say the engine is missing rather than start', () async {
      final adapter = FakeProxyCoreAdapter(engineAvailable: false);

      final result = await ConnectionRepository(
        adapter,
      ).connect(dialableConfig('a'), testTunnelOptions());

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.engineMissing,
      );
      expect(adapter.events, isEmpty);
    });

    test('should say the engine is missing for WARP too', () async {
      final adapter = FakeProxyCoreAdapter(engineAvailable: false);

      final result = await ConnectionRepository(
        adapter,
      ).connectWarp(WarpMode.warp, testTunnelOptions());

      expect(
        result.getLeft().toNullable()?.userFacingKey,
        UserFacingErrorKeys.engineMissing,
      );
      expect(adapter.events, isEmpty);
    });
  });

  group('connect in tunnel mode', () {
    // Every start and stop of the engine and the helper, in order, for the
    // tests that hand both fakes this list.
    late List<String> events;

    // Every method the system proxy channel was called with.
    late List<String> systemProxyMethods;

    setUp(() {
      events = [];
      systemProxyMethods = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_systemProxyChannel, (call) async {
            systemProxyMethods.add(call.method);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_systemProxyChannel, null);
    });

    test(
      'should start the engine bound to the physical interface, then the helper',
      () async {
        final adapter = FakeProxyCoreAdapter(
          startsCleanly: true,
          events: events,
        );
        final helper = FakeTunnelHelper(events: events);
        final repository = ConnectionRepository(adapter, tunnelHelper: helper);

        final result = await repository.connect(
          dialableConfig('a'),
          _tunnelOptions,
        );

        expect(result.getRight().toNullable(), TunnelMode.vpn);
        expect(adapter.lastBindPhysicalInterface, isTrue);
        expect(
          adapter.lastAppRouting,
          AppRouting.none,
          reason:
              'every tunnelled connection reaches the engine as the '
              "helper's, so the helper applies the choice",
        );
        expect(helper.lastSocksPort, repository.activeSocksPort);
        expect(helper.lastAppRouting, _onlyThroughBrowser);
        expect(events, [
          'helper.stop',
          'engine.stop',
          'engine.start',
          'helper.start',
        ]);
      },
    );

    test('should never set the system proxy', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(startsCleanly: true),
        tunnelHelper: FakeTunnelHelper(),
      );

      final result = await repository.connect(
        dialableConfig('a'),
        _tunnelOptions,
      );

      expect(result.isRight(), isTrue);
      expect(systemProxyMethods, isNot(contains('setProxy')));
    });

    test(
      'should fail a declined prompt as ElevationDeclinedFailure and stop the engine and helper',
      () async {
        final adapter = FakeProxyCoreAdapter(
          startsCleanly: true,
          events: events,
        );
        final helper = FakeTunnelHelper(
          startFailure: const ElevationDeclinedFailure(),
          events: events,
        );
        final repository = ConnectionRepository(adapter, tunnelHelper: helper);

        final result = await repository.connect(
          dialableConfig('a'),
          _tunnelOptions,
        );

        final failure = result.getLeft().toNullable();
        expect(failure, isA<ElevationDeclinedFailure>());
        expect(failure?.userFacingKey, UserFacingErrorKeys.elevationDeclined);
        expect(events, [
          'helper.stop',
          'engine.stop',
          'engine.start',
          'helper.start',
          'helper.stop',
          'engine.stop',
        ]);
        expect(await adapter.isRunning(), isFalse);
        expect(helper.isRunning, isFalse);
        expect(systemProxyMethods, isNot(contains('setProxy')));
        // The service only calls the channel on Windows.
        expect(
          systemProxyMethods.lastOrNull,
          Platform.isWindows ? 'clearProxy' : isNull,
        );
      },
    );

    test(
      'should not launch the helper for a connect called off before the helper starts',
      () async {
        final helper = FakeTunnelHelper(events: events);
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true, events: events),
          tunnelHelper: helper,
        );

        await repository.connect(
          dialableConfig('a'),
          _tunnelOptions,
          isCancelled: () => true,
        );

        expect(
          helper.startCount,
          0,
          reason: 'an admin prompt for a connect the user already called off',
        );
        expect(events.last, 'engine.start');
      },
    );

    test(
      'should not start the helper when the engine fails to start',
      () async {
        final helper = FakeTunnelHelper(events: events);
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(
            startFailure: Exception(
              'Failed to start Proxy mode: engine exited',
            ),
            events: events,
          ),
          tunnelHelper: helper,
        );

        final result = await repository.connect(
          dialableConfig('a'),
          _tunnelOptions,
        );

        expect(result.getLeft().toNullable(), isA<TunnelFailure>());
        expect(
          helper.startCount,
          0,
          reason: 'an admin prompt for a tunnel with no engine behind it',
        );
        expect(events, [
          'helper.stop',
          'engine.stop',
          'engine.start',
          'helper.stop',
          'engine.stop',
        ]);
      },
    );

    test('should stop a helper left running before connecting again', () async {
      for (final options in [
        _tunnelOptions,
        testTunnelOptions(systemProxy: true),
      ]) {
        events.clear();
        final helper = FakeTunnelHelper(events: events)..isRunning = true;
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true, events: events),
          tunnelHelper: helper,
        );

        await repository.connect(dialableConfig('a'), options);

        expect(
          events.take(2),
          ['helper.stop', 'engine.stop'],
          reason:
              'systemProxy: ${options.systemProxy}. Its tunnel would hand '
              'traffic to an engine that is gone.',
        );
      }
    });

    test(
      'should not start the helper when the system proxy is chosen',
      () async {
        final adapter = FakeProxyCoreAdapter(startsCleanly: true);
        final helper = FakeTunnelHelper();
        final repository = ConnectionRepository(adapter, tunnelHelper: helper);

        await repository.connect(
          dialableConfig('a'),
          testTunnelOptions(systemProxy: true),
        );

        expect(helper.startCount, 0);
        expect(adapter.lastBindPhysicalInterface, isFalse);
        // The channel the tunnel leaves alone is the one this mode sets, where
        // the service calls it at all.
        expect(
          systemProxyMethods,
          Platform.isWindows ? contains('setProxy') : isEmpty,
        );
      },
    );

    test('should not start the helper when proxy only is chosen', () async {
      final adapter = FakeProxyCoreAdapter(startsCleanly: true);
      final helper = FakeTunnelHelper();
      final repository = ConnectionRepository(adapter, tunnelHelper: helper);

      await repository.connect(
        dialableConfig('a'),
        testTunnelOptions(proxyOnly: true),
      );

      expect(helper.startCount, 0);
      expect(adapter.lastBindPhysicalInterface, isFalse);
    });

    test('should never start a tunnel without a helper', () async {
      final adapter = FakeProxyCoreAdapter(startsCleanly: true);
      final repository = ConnectionRepository(adapter);

      final result = await repository.connect(
        dialableConfig('a'),
        _tunnelOptions,
      );

      expect(result.getRight().toNullable(), TunnelMode.proxy);
      expect(adapter.lastBindPhysicalInterface, isFalse);
      expect(adapter.lastAppRouting, _onlyThroughBrowser);
      await expectLater(repository.tunnelLost, emitsDone);
    }, skip: _startsProxy ? null : _proxySkipReason);

    test('should stop the helper on disconnect', () async {
      final helper = FakeTunnelHelper(events: events);
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(startsCleanly: true, events: events),
        tunnelHelper: helper,
      );
      await repository.connect(dialableConfig('a'), _tunnelOptions);
      events.clear();

      final result = await repository.disconnect();

      expect(result.isRight(), isTrue);
      expect(events, ['helper.stop', 'engine.stop']);
      expect(helper.isRunning, isFalse);
    });

    test('should stop the helper even when the engine will not stop', () async {
      final helper = FakeTunnelHelper()..isRunning = true;
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(stopFailure: Exception('engine would not stop')),
        tunnelHelper: helper,
      );

      final result = await repository.disconnect();

      expect(result.isLeft(), isTrue);
      expect(helper.isRunning, isFalse);
    });

    test(
      'should read the connection as down once the helper is gone',
      () async {
        final helper = FakeTunnelHelper();
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true),
          tunnelHelper: helper,
        );
        await repository.connect(dialableConfig('a'), _tunnelOptions);
        expect(await repository.isConnectionActive(_tunnelOptions), isTrue);
        var losses = 0;
        final subscription = repository.tunnelLost.listen((_) => losses++);
        addTearDown(subscription.cancel);

        helper.loseTunnel();
        await pumpEventQueue();

        expect(losses, 1);
        expect(
          await repository.isConnectionActive(_tunnelOptions),
          isFalse,
          reason: 'the engine is still running, and nothing hands it traffic',
        );
      },
    );

    // The mode can be changed in Settings while connected and only takes
    // effect on the next connect, so the health check has to judge the
    // connection that is up rather than the one Settings would make now.
    test(
      'should judge a proxy connection by how it was made, not by the mode chosen since',
      () async {
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true),
          tunnelHelper: FakeTunnelHelper(),
        );
        await repository.connect(
          dialableConfig('a'),
          testTunnelOptions(proxyOnly: true),
        );

        expect(
          await repository.isConnectionActive(_tunnelOptions),
          isTrue,
          reason:
              'read as down, the connection would be published as ready '
              'with its engine left running',
        );
      },
      skip: _startsProxy ? null : _proxySkipReason,
    );

    test(
      'should judge a tunnel connection by how it was made, not by the mode chosen since',
      () async {
        final helper = FakeTunnelHelper();
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true),
          tunnelHelper: helper,
        );
        await repository.connect(dialableConfig('a'), _tunnelOptions);

        helper.loseTunnel();

        for (final options in [
          testTunnelOptions(proxyOnly: true),
          testTunnelOptions(systemProxy: true),
        ]) {
          expect(
            await repository.isConnectionActive(options),
            isFalse,
            reason:
                'proxyOnly: ${options.proxyOnly}. The engine is still '
                'running, and nothing hands it traffic.',
          );
        }
      },
    );

    test(
      'should report a connect made through the helper until it is stopped',
      () async {
        final repository = ConnectionRepository(
          FakeProxyCoreAdapter(startsCleanly: true),
          tunnelHelper: FakeTunnelHelper(),
        );
        await repository.connect(dialableConfig('a'), _tunnelOptions);

        expect(repository.connectedThroughHelper, isTrue);
        expect(repository.helperLost, isFalse);

        await repository.disconnect();

        expect(repository.connectedThroughHelper, isFalse);
        expect(repository.helperLost, isFalse);
      },
    );

    // A language change rebuilds the repository, while the helper has a
    // provider of its own and stays.
    test(
      'should remember a helper connection across a repository rebuild',
      () async {
        final helper = FakeTunnelHelper();
        final adapter = FakeProxyCoreAdapter(startsCleanly: true);
        await ConnectionRepository(
          adapter,
          tunnelHelper: helper,
        ).connect(dialableConfig('a'), _tunnelOptions);

        helper.loseTunnel();
        final rebuilt = ConnectionRepository(adapter, tunnelHelper: helper);

        expect(rebuilt.connectedThroughHelper, isTrue);
        expect(rebuilt.helperLost, isTrue);
      },
    );

    test('should report the helper lost once it goes on its own', () async {
      final helper = FakeTunnelHelper();
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(startsCleanly: true),
        tunnelHelper: helper,
      );
      await repository.connect(dialableConfig('a'), _tunnelOptions);

      helper.loseTunnel();

      expect(repository.helperLost, isTrue);
      expect(
        repository.connectedThroughHelper,
        isTrue,
        reason: 'the connection was made through it, and nothing has ended it',
      );
    });

    test('should not report a helper for a connect made without one', () async {
      final helper = FakeTunnelHelper();
      final connects = [
        (
          ConnectionRepository(
            FakeProxyCoreAdapter(startsCleanly: true),
            tunnelHelper: helper,
          ),
          testTunnelOptions(systemProxy: true),
        ),
        (
          ConnectionRepository(
            FakeProxyCoreAdapter(startsCleanly: true),
            tunnelHelper: helper,
          ),
          testTunnelOptions(proxyOnly: true),
        ),
        (
          ConnectionRepository(FakeProxyCoreAdapter(startsCleanly: true)),
          _tunnelOptions,
        ),
      ];

      for (final (repository, options) in connects) {
        await repository.connect(dialableConfig('a'), options);

        expect(repository.connectedThroughHelper, isFalse);
        expect(
          repository.helperLost,
          isFalse,
          reason: 'no helper is running, and none was asked to',
        );
      }
    });

    test('should not count its own tunnel as another VPN', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: FakeOtherVpnDataSource(vpnOn: true),
        tunnelHelper: FakeTunnelHelper()..isRunning = true,
      );

      expect(
        await repository.isOtherVpnOn(),
        isFalse,
        reason: 'Windows reads the Begzar adapter as a VPN like any other',
      );
    });
  });

  group('ConnectionRepository.measurePing', () {
    test('should report the fastest latency the engine measured', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(
          latencySamples: const [
            LatencySample(url: 'https://a.test', elapsedMs: 120),
            LatencySample(url: 'https://b.test', elapsedMs: 80),
          ],
        ),
      );

      final result = await repository.measurePing();

      expect(result.isSuccessful, isTrue);
      expect(result.latencyMs, 80);
    });

    test('should fail when every measurement failed', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(
          latencySamples: const [
            LatencySample(url: 'https://a.test', elapsedMs: -1),
          ],
        ),
      );

      final result = await repository.measurePing();

      expect(result.isSuccessful, isFalse);
    });
  });

  group('ConnectionRepository.isPassingTraffic', () {
    test('should pass when either probe page answers', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(
          latencySamples: const [
            LatencySample(url: 'https://a.test', elapsedMs: -1),
            LatencySample(url: 'https://b.test', elapsedMs: 90),
          ],
        ),
      );

      expect(await repository.isPassingTraffic(), isTrue);
    });

    test('should fail when neither probe page answers', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(
          latencySamples: const [
            LatencySample(url: 'https://a.test', elapsedMs: -1),
            LatencySample(url: 'https://b.test', elapsedMs: -1),
          ],
        ),
      );

      expect(await repository.isPassingTraffic(), isFalse);
    });

    test('should read a check that could not run as no traffic', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter()..trafficProbeFailure = StateError('engine gone'),
      );

      expect(await repository.isPassingTraffic(), isFalse);
    });
  });

  group('ConnectionRepository.isOtherVpnOn', () {
    test('should report a VPN that is on while the tunnel is down', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: FakeOtherVpnDataSource(vpnOn: true),
      );

      expect(await repository.isOtherVpnOn(), isTrue);
    });

    test('should not take its own tunnel for another VPN', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(tunnelActive: true),
        otherVpn: FakeOtherVpnDataSource(vpnOn: true),
      );

      expect(
        await repository.isOtherVpnOn(),
        isFalse,
        reason: 'the platform sees a VPN either way, and this one is ours',
      );
    });

    test('should read a check that throws as no other VPN', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: FakeOtherVpnDataSource(
          vpnOn: true,
          failure: MissingPluginException(),
        ),
      );

      expect(
        await repository.isOtherVpnOn(),
        isFalse,
        reason: 'a broken check must not lock everyone out of connecting',
      );
    });
  });

  group('ConnectionRepository.turnOffOtherVpn', () {
    test('should ask the platform to turn the other VPN off', () async {
      final otherVpn = FakeOtherVpnDataSource(vpnOn: true);
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: otherVpn,
      );

      await repository.turnOffOtherVpn();

      expect(otherVpn.turnOffs, 1);
    });

    test('should swallow a refusal and leave the check to say so', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: FakeOtherVpnDataSource(
          vpnOn: true,
          failure: PlatformException(code: 'VPN_PERMISSION_DENIED'),
        ),
      );

      await expectLater(repository.turnOffOtherVpn(), completes);
    });
  });

  group('ConnectionRepository.openVpnSettings', () {
    test('should report a settings page that would not open', () async {
      final repository = ConnectionRepository(
        FakeProxyCoreAdapter(),
        otherVpn: FakeOtherVpnDataSource(failure: MissingPluginException()),
      );

      expect(await repository.openVpnSettings(), isFalse);
    });
  });
}
