import 'dart:async';

import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/application/services/connection_service.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../connection_test_doubles.dart';

void main() {
  late FakeConnectionRepository connections;

  /// [ConnectionService.connectAuto] shuffles the config list and draws its
  /// pick at random, so the tests that assert *which* config dialled pin both
  /// first. [NoShuffleRandom] leaves the order alone and always draws the last
  /// entry of the shortlist. The randomness itself is covered by its own tests.
  ConnectionService orderedService() =>
      testConnectionService(connections, random: const NoShuffleRandom());

  /// Five configs answering in a known order: b, d, e are the three fastest.
  const Map<String, int> fiveDelays = {
    'a': 50,
    'b': 10,
    'c': 40,
    'd': 20,
    'e': 30,
  };
  const Set<String> threeFastest = {'b', 'd', 'e'};

  List<ProxyConfigEntity> configsNamed(Iterable<String> names) =>
      names.map(testConfig).toList();

  group('connectAuto', () {
    test('should dial from the three fastest answers', () async {
      connections = FakeConnectionRepository(probeDelays: fiveDelays);

      final result = await orderedService().connectAuto(
        configsNamed(fiveDelays.keys),
      );

      expect(result?.isRight(), isTrue);
      expect(
        connections.connectedConfigNames,
        ['e'],
        reason:
            'NoShuffleRandom draws the last of b, d, e — the shortlist '
            'sorted fastest first',
      );
    });

    test('should only ever dial one of the three fastest', () async {
      // A real unseeded Random, which is what production uses.
      for (var attempt = 0; attempt < 30; attempt++) {
        final repository = FakeConnectionRepository(probeDelays: fiveDelays);

        await testConnectionService(
          repository,
        ).connectAuto(configsNamed(fiveDelays.keys));

        expect(threeFastest, contains(repository.connectedConfigNames.single));
      }
    });

    test('should spread connects across the three fastest', () async {
      // Thirty draws from three: landing on one config every time would be a
      // 1-in-10^13 coincidence, so a single distinct name means no draw.
      final dialled = <String>{};
      for (var attempt = 0; attempt < 30; attempt++) {
        final repository = FakeConnectionRepository(probeDelays: fiveDelays);

        await testConnectionService(
          repository,
        ).connectAuto(configsNamed(fiveDelays.keys));

        dialled.add(repository.connectedConfigNames.single);
      }

      expect(
        dialled.length,
        greaterThan(1),
        reason: 'quick connect sent every user to the same fastest server',
      );
    });

    test('should never dial a config that did not answer', () async {
      connections = FakeConnectionRepository(probeDelays: {'c': 900});

      final result = await orderedService().connectAuto(
        configsNamed(['a', 'b', 'c']),
      );

      expect(result?.isRight(), isTrue);
      expect(connections.connectedConfigNames, ['c']);
    });

    test('should probe every candidate in one batch', () async {
      connections = FakeConnectionRepository(probeDelays: fiveDelays);

      await orderedService().connectAuto(configsNamed(fiveDelays.keys));

      expect(connections.probeStopAfters, hasLength(1));
      expect(connections.testedConfigNames, fiveDelays.keys.toList());
    });

    test('should ask the probe to stop after three answers', () async {
      // The pick only ever draws from three, so a dead config still timing
      // out after three have answered would hold the connect for nothing.
      connections = FakeConnectionRepository(probeDelays: fiveDelays);

      await orderedService().connectAuto(configsNamed(fiveDelays.keys));

      expect(connections.probeStopAfters, [threeFastest.length]);
    });

    test('should never dial a server that reaches only Google', () async {
      connections = FakeConnectionRepository(
        probeDelays: {'a': 10, 'b': 20},
        googleOnly: {'b'},
      );

      final result = await orderedService().connectAuto(
        configsNamed(['a', 'b']),
      );

      expect(result?.isRight(), isTrue);
      expect(connections.connectedConfigNames, [
        'a',
      ], reason: 'NoShuffleRandom would draw b were it still on the shortlist');
    });

    test(
      'should draw from the three fastest that reach outside Google',
      () async {
        connections = FakeConnectionRepository(
          probeDelays: fiveDelays,
          googleOnly: {'e'},
        );

        await orderedService().connectAuto(configsNamed(fiveDelays.keys));

        expect(
          connections.connectedConfigNames,
          ['d'],
          reason:
              'e is among the three fastest to answer Google but reaches '
              'nothing else, so the shortlist is b, d and NoShuffleRandom '
              'draws d',
        );
      },
    );

    test(
      'should check every one of the three fastest outside Google',
      () async {
        connections = FakeConnectionRepository(probeDelays: fiveDelays);

        await orderedService().connectAuto(configsNamed(fiveDelays.keys));

        expect(connections.outsideGoogleChecks, [
          ['b', 'd', 'e'],
        ]);
        expect(connections.outsideGoogleStopAfters, [
          0,
        ], reason: 'each of the three is a candidate for the draw');
      },
    );

    test(
      'should fall back to the Google answers when none reaches outside',
      () async {
        // Every server failing the second host reads as that host being
        // down, and a connect it would otherwise refuse goes ahead as before.
        connections = FakeConnectionRepository(
          probeDelays: fiveDelays,
          googleOnly: fiveDelays.keys.toSet(),
        );

        final result = await orderedService().connectAuto(
          configsNamed(fiveDelays.keys),
        );

        expect(result?.isRight(), isTrue);
        expect(connections.connectedConfigNames, ['e']);
      },
    );

    test('should hand back the config that dialled, not unit', () async {
      // The candidates are shuffled and the pick is drawn, so the right-hand
      // value is the only way a caller can find out where it ended up. The
      // premium list's last-connected badge is recorded from it.
      connections = FakeConnectionRepository(probeDelays: {'b': 10});

      final result = await orderedService().connectAuto(
        configsNamed(['a', 'b']),
      );

      expect(result?.toNullable()?.name, 'b');
    });

    test('should surface a failed dial without dialling another', () async {
      connections = FakeConnectionRepository(
        probeDelays: fiveDelays,
        connectResult: left(VpnPermissionFailure()),
      );

      final result = await orderedService().connectAuto(
        configsNamed(fiveDelays.keys),
      );

      expect(result?.getLeft().toNullable(), isA<VpnPermissionFailure>());
      expect(connections.connectedConfigNames, hasLength(1));
    });

    test('should fail without a teardown when no config answers', () async {
      connections = FakeConnectionRepository(
        testVerdicts: {'a': right(false), 'b': right(false)},
      );

      final result = await orderedService().connectAuto(
        configsNamed(['a', 'b']),
      );

      final error = result?.getLeft().toNullable();
      expect(error, isA<NoWorkingConfigFailure>());
      expect((error as NoWorkingConfigFailure).attemptedConfigs, 2);
      expect(connections.testedConfigNames, ['a', 'b']);
      expect(
        connections.disconnectCount,
        0,
        reason: 'probing runs beside the tunnel, so there is none to tear down',
      );
      expect(connections.connectedConfigNames, isEmpty);
      expect(connections.outsideGoogleChecks, isEmpty);
    });

    test('fails without a teardown when the config list is empty', () async {
      connections = FakeConnectionRepository();

      final result = await orderedService().connectAuto(const []);

      final error = result?.getLeft().toNullable();
      expect(error, isA<NoWorkingConfigFailure>());
      expect((error as NoWorkingConfigFailure).attemptedConfigs, 0);
      expect(connections.disconnectCount, 0);
    });
  });

  group('connectAuto config ordering', () {
    /// Ten configs that all fail, so every one gets tried and the full order is
    /// observable.
    List<String> names(int count) =>
        List.generate(count, (i) => String.fromCharCode(97 + i));

    FakeConnectionRepository allFailing(List<String> forNames) =>
        FakeConnectionRepository(
          testVerdicts: {for (final n in forNames) n: right(false)},
        );

    test('NoShuffleRandom leaves the order untouched', () {
      // Guards the assumption the other tests rely on. If the SDK's shuffle
      // stops being Fisher-Yates in this exact shape, this fails first and
      // says so, rather than quietly scrambling the assertions above.
      final list = names(10);
      final shuffled = [...list]..shuffle(const NoShuffleRandom());

      expect(shuffled, list);
    });

    test('does not probe the same config first on every connect', () async {
      // Probe order decides which configs start first under the engine's
      // worker cap, so a fixed order would keep favouring the same servers.
      final firstTried = <String>{};

      // A real unseeded Random, which is what production uses. Ten configs over
      // twenty attempts: seeing one name every time would be a 1-in-10^19
      // coincidence, so a single distinct value means the shuffle is absent.
      for (var attempt = 0; attempt < 20; attempt++) {
        final configNames = names(10);
        final repository = allFailing(configNames);

        await testConnectionService(
          repository,
        ).connectAuto(configNames.map(testConfig).toList());

        firstTried.add(repository.testedConfigNames.first);
      }

      expect(
        firstTried.length,
        greaterThan(1),
        reason: 'quick connect kept starting at the same server every time',
      );
    });

    test(
      'shuffles rather than samples, so every config is still tried',
      () async {
        final configNames = names(10);
        final repository = allFailing(configNames);

        await testConnectionService(
          repository,
        ).connectAuto(configNames.map(testConfig).toList());

        expect(
          repository.testedConfigNames..sort(),
          configNames,
          reason: 'a config must not be dropped or tried twice by the shuffle',
        );
      },
    );

    test("leaves the caller's list in its original order", () async {
      // The premium screen holds the same list it hands to quick connect. An
      // in-place shuffle would reorder the servers under the user.
      final configNames = names(10);
      final callerList = configNames.map(testConfig).toList();

      await testConnectionService(
        allFailing(configNames),
      ).connectAuto(callerList);

      expect(callerList.map((c) => c.name).toList(), configNames);
    });
  });

  group('connect', () {
    test('rejects an unsupported scheme before touching the tunnel', () async {
      // testConfig carries a scheme the validator does not accept, so this
      // exercises the real domain rule rather than a stubbed verdict.
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});

      final result = await testConnectionService(
        connections,
      ).connect(testConfig('a'));

      expect(result?.getLeft().toNullable(), isA<InvalidConfigFailure>());
      expect(connections.testedConfigNames, isEmpty);
      expect(connections.connectedConfigNames, isEmpty);
    });

    test('rejects a config with no name', () async {
      connections = FakeConnectionRepository();

      final result = await testConnectionService(connections).connect(
        ProxyConfigEntity(
          url: '${ProxyConfigValidator.supportedSchemes.first}host',
          name: '',
        ),
      );

      expect(result?.getLeft().toNullable(), isA<InvalidConfigFailure>());
      expect(connections.testedConfigNames, isEmpty);
    });

    test('stops when the config fails its test', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(false)});

      final result = await testConnectionService(
        connections,
      ).connect(dialableConfig('a'));

      expect(result?.getLeft().toNullable(), isA<ProxyTestFailure>());
      expect(connections.connectedConfigNames, isEmpty);
      expect(
        connections.disconnectCount,
        1,
        reason: 'testing may have left an Apple NE tunnel up',
      );
    });

    test('never shuffles a hand-picked config', () async {
      // connect() takes exactly one config; the shuffle belongs to connectAuto.
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)});

      await testConnectionService(connections).connect(dialableConfig('a'));

      expect(connections.testedConfigNames, ['a']);
      expect(connections.connectedConfigNames, ['a']);
    });
  });

  // A cancel reaches the service while one of its steps is still awaiting the
  // engine. Nothing can take that step back, so what these pin is what happens
  // when it returns: nothing further is started, and whatever it brought up is
  // taken down again.
  group('cancelConnect', () {
    test(
      'should stop the engine without waiting for the step in flight',
      () async {
        connections = FakeConnectionRepository(probeDelays: {'a': 10})
          ..holdProbe = Completer<void>();
        final service = orderedService();

        final pending = service.connectAuto(configsNamed(['a']));
        await pumpEventQueue();
        await service.cancelConnect();

        expect(
          connections.disconnectCount,
          1,
          reason: 'stopping the engine is what cuts a running probe short',
        );

        connections.holdProbe!.complete();
        await pending;
      },
    );

    test('should not dial once the probe it cut short returns', () async {
      connections = FakeConnectionRepository(probeDelays: {'a': 10})
        ..holdProbe = Completer<void>();
      final service = orderedService();

      final pending = service.connectAuto(configsNamed(['a']));
      await pumpEventQueue();
      await service.cancelConnect();
      connections.holdProbe!.complete();

      expect(
        await pending,
        isNull,
        reason: 'a connect called off is not a connect that failed',
      );
      expect(connections.connectedConfigNames, isEmpty);
    });

    test(
      'should not dial once the check outside Google it cut short returns',
      () async {
        connections = FakeConnectionRepository(probeDelays: {'a': 10})
          ..holdOutsideGoogleCheck = Completer<void>();
        final service = orderedService();

        final pending = service.connectAuto(configsNamed(['a']));
        await pumpEventQueue();
        await service.cancelConnect();
        connections.holdOutsideGoogleCheck!.complete();

        expect(await pending, isNull);
        expect(connections.connectedConfigNames, isEmpty);
      },
    );

    test('should take down a tunnel the cancelled dial brought up', () async {
      connections = FakeConnectionRepository(probeDelays: {'a': 10})
        ..holdDial = Completer<void>();
      final service = orderedService();

      final pending = service.connectAuto(configsNamed(['a']));
      await pumpEventQueue();
      await service.cancelConnect();
      connections.holdDial!.complete();

      expect(await pending, isNull);
      expect(
        connections.connectionActive,
        isFalse,
        reason:
            'the stop at cancel landed before the dial finished, so the '
            'tunnel came up after it',
      );
    });

    test(
      'should not dial a hand-picked config once its test returns',
      () async {
        connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
          ..holdProbe = Completer<void>();
        final service = testConnectionService(connections);

        final pending = service.connect(dialableConfig('a'));
        await pumpEventQueue();
        await service.cancelConnect();
        connections.holdProbe!.complete();

        expect(await pending, isNull);
        expect(connections.connectedConfigNames, isEmpty);
      },
    );

    test('should take down a tunnel a hand-picked dial brought up', () async {
      connections = FakeConnectionRepository(testVerdicts: {'a': right(true)})
        ..holdDial = Completer<void>();
      final service = testConnectionService(connections);

      final pending = service.connect(dialableConfig('a'));
      await pumpEventQueue();
      await service.cancelConnect();
      connections.holdDial!.complete();

      expect(await pending, isNull);
      expect(connections.connectionActive, isFalse);
    });

    test(
      'should hold the next connect until the cancelled dial has unwound',
      () async {
        connections = FakeConnectionRepository(probeDelays: {'a': 10})
          ..holdDial = Completer<void>();
        final service = orderedService();

        final cancelled = service.connectAuto(configsNamed(['a']));
        await pumpEventQueue();
        await service.cancelConnect();
        final next = service.connectAuto(configsNamed(['a']));
        await pumpEventQueue();

        expect(
          connections.probeStopAfters,
          hasLength(1),
          reason:
              'the teardown still to come stops the engine, which would cut '
              'a new probe short',
        );

        connections.holdDial!.complete();
        await cancelled;

        expect((await next)?.isRight(), isTrue);
        expect(
          connections.connectionActive,
          isTrue,
          reason:
              'the cancelled dial was taken down before the next one came '
              'up, not after',
        );
      },
    );

    test('should leave the connect after a settled cancel alone', () async {
      connections = FakeConnectionRepository(probeDelays: {'a': 10});
      final service = orderedService();

      await service.cancelConnect();
      final result = await service.connectAuto(configsNamed(['a']));

      expect(result?.isRight(), isTrue);
      expect(connections.connectedConfigNames, ['a']);
    });
  });

  // The verdict is read off a second check rather than off the attempt, so a
  // platform that cannot turn the other VPN off never claims it did.
  group('clearOtherVpn', () {
    test('should find nothing to do when no other VPN is on', () async {
      connections = FakeConnectionRepository();

      final verdict = await testConnectionService(connections).clearOtherVpn();

      expect(verdict, OtherVpnVerdict.none);
      expect(connections.otherVpnTurnOffs, 0);
    });

    test('should report a VPN it turned off', () async {
      connections = FakeConnectionRepository()..otherVpnOn = true;

      final verdict = await testConnectionService(connections).clearOtherVpn();

      expect(verdict, OtherVpnVerdict.disconnected);
      expect(connections.otherVpnTurnOffs, 1);
    });

    test('should report a VPN that stayed on after the attempt', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;

      final verdict = await testConnectionService(connections).clearOtherVpn();

      expect(verdict, OtherVpnVerdict.stillOn);
      expect(
        connections.otherVpnTurnOffs,
        1,
        reason: 'it tries once, then waits for the network to say',
      );
    });
  });
}
