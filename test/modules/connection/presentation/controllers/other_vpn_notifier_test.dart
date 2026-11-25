import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../connection_test_doubles.dart';

void main() {
  late FakeConnectionRepository connections;
  late ProviderContainer container;

  /// [goAnyway] is how the warning gets answered; null leaves it unanswered,
  /// as a warning still on screen is.
  void buildContainer({bool? goAnyway = false}) {
    container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(connections),
        connectionServiceProvider.overrideWith(
          (ref) =>
              testConnectionService(ref.watch(connectionRepositoryProvider)),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (goAnyway != null) {
      answerOtherVpnWarnings(container, goAnyway: goAnyway);
    }
  }

  group('OtherVpnNotifier.clear', () {
    test('should raise nothing when no other VPN is on', () async {
      connections = FakeConnectionRepository();
      buildContainer();

      final verdict = await container.read(otherVpnProvider.notifier).clear();

      expect(verdict, OtherVpnVerdict.none);
      expect(container.read(otherVpnProvider), isNull);
    });

    test('should raise a notice for a VPN it turned off', () async {
      connections = FakeConnectionRepository()..otherVpnOn = true;
      buildContainer();

      await container.read(otherVpnProvider.notifier).clear();

      expect(
        container.read(otherVpnProvider)?.verdict,
        OtherVpnVerdict.disconnected,
      );
    });

    test('should raise a warning for a VPN that stayed on', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer();

      await container.read(otherVpnProvider.notifier).clear();

      expect(
        container.read(otherVpnProvider)?.verdict,
        OtherVpnVerdict.stillOn,
      );
    });

    test('should hand back stillOn when the warning is closed', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer();

      final verdict = await container.read(otherVpnProvider.notifier).clear();

      expect(verdict, OtherVpnVerdict.stillOn);
    });

    test('should let the user go on with it on', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer(goAnyway: true);

      final verdict = await container.read(otherVpnProvider.notifier).clear();

      expect(verdict, OtherVpnVerdict.overridden);
    });

    test('should wait for the warning to be answered', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer(goAnyway: null);

      final notifier = container.read(otherVpnProvider.notifier);
      var answered = false;
      final verdict = notifier.clear().whenComplete(() => answered = true);
      await pumpEventQueue(times: turnsToGiveUpOnAVpn);

      expect(answered, isFalse, reason: 'nothing goes on before the user says');

      notifier.answerWarning(goAnyway: true);
      expect(await verdict, OtherVpnVerdict.overridden);
    });

    test('should close an unanswered warning as stillOn on dispose', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer(goAnyway: null);

      final verdict = container.read(otherVpnProvider.notifier).clear();
      await pumpEventQueue(times: turnsToGiveUpOnAVpn);
      container.dispose();

      expect(await verdict, OtherVpnVerdict.stillOn);
    });

    test('should raise the same warning again on the next attempt', () async {
      connections = FakeConnectionRepository()
        ..otherVpnOn = true
        ..otherVpnYields = false;
      buildContainer();

      var raised = 0;
      container.listen(otherVpnProvider, (_, _) => raised++);

      final notifier = container.read(otherVpnProvider.notifier);
      await notifier.clear();
      await notifier.clear();

      expect(
        raised,
        2,
        reason: 'a second tap on a VPN still on has to be told so again',
      );
    });
  });

  group('OtherVpnNotifier.isOn', () {
    test('should only check, never turning anything off', () async {
      connections = FakeConnectionRepository()..otherVpnOn = true;
      buildContainer();

      expect(await container.read(otherVpnProvider.notifier).isOn(), isTrue);
      expect(connections.otherVpnTurnOffs, 0);
      expect(container.read(otherVpnProvider), isNull);
    });
  });

  group('OtherVpnNotifier.openSettings', () {
    test('should open the system VPN settings', () async {
      connections = FakeConnectionRepository();
      buildContainer();

      await container.read(otherVpnProvider.notifier).openSettings();

      expect(connections.vpnSettingsOpened, 1);
    });
  });
}
