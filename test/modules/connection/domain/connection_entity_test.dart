import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for `ConnectionNotifier` with none of its I/O, so the test is
/// about what Riverpod does with the entity rather than about connecting.
class _StatusProbe extends Notifier<ConnectionEntity> {
  @override
  ConnectionEntity build() => ConnectionEntity.create();

  void apply(ConnectionEntity Function(ConnectionEntity) transition) {
    state = transition(state);
  }
}

final _probeProvider = NotifierProvider<_StatusProbe, ConnectionEntity>(
  _StatusProbe.new,
);

void main() {
  group('equality covers what a transition changes', () {
    test('two states of one connection differ when the status differs', () {
      final ready = ConnectionEntity.create();

      expect(ready, isNot(ready.connecting()));
      expect(ready.connecting(), isNot(ready.connected()));
      expect(ready.connected(), isNot(ready.disconnecting()));
    });

    test('an error and its message are distinguishing', () {
      final ready = ConnectionEntity.create();

      expect(ready.failed('boom'), isNot(ready));
      expect(ready.failed('boom'), isNot(ready.failed('other')));
      expect(ready.failed('boom'), ready.failed('boom'));
    });

    test('a fresh ping result is distinguishing', () {
      final connected = ConnectionEntity.create().connected();
      final measured = connected.withPingResult(
        PingResult(
          latencyMs: 120,
          isSuccessful: true,
          timestamp: DateTime.utc(2026),
        ),
      );

      expect(measured, isNot(connected));
      expect(
        measured.withPingResult(
          PingResult(
            latencyMs: 340,
            isSuccessful: true,
            timestamp: DateTime.utc(2026),
          ),
        ),
        isNot(measured),
      );
    });

    test('an unchanged state still equals itself, and hashes with it', () {
      final ready = ConnectionEntity.create();
      final same = ready.copyWith();

      expect(same, ready);
      expect(same.hashCode, ready.hashCode);
    });

    // The entity carries no identity, so "a different connection" is not a
    // thing it can express — there is only ever one. Two fresh ones say the
    // same thing and so are the same thing. This used to be the opposite, and
    // the generated id that made it so was what broke transition equality.
    test('two connections saying the same thing are equal', () {
      expect(ConnectionEntity.create(), const ConnectionEntity.create());
      expect(
        ConnectionEntity.create().hashCode,
        const ConnectionEntity.create().hashCode,
      );
    });

    // Stamped rather than measured, so reconnecting is a new state even though
    // the status matches. Written with explicit times rather than two
    // connected() calls, which would compare two readings of the clock.
    test('the connect timestamp distinguishes two connected states', () {
      const ready = ConnectionEntity.create();
      final at = DateTime.utc(2026, 8, 28, 12);

      ConnectionEntity connectedAt(DateTime when) =>
          ready.copyWith(status: ConnectionStatus.connected, connectedAt: when);

      expect(connectedAt(at), connectedAt(at));
      expect(
        connectedAt(at),
        isNot(connectedAt(at.add(const Duration(seconds: 1)))),
      );
    });
  });

  // The post-connect ad is owed once per connect, and a relaunch reaches
  // connected by the same transition a connect does. Whether the tunnel was
  // dialled or found is the only thing that tells them apart, so the entity
  // has to carry it and every route out of connected has to drop it.
  group('an adopted tunnel says so', () {
    final at = DateTime.utc(2026, 8, 28, 12);

    test('dialling is not adopting', () {
      expect(ConnectionEntity.create().connected(at: at).adopted, isFalse);
    });

    test('adopting is recorded on the connected state', () {
      final adopted = ConnectionEntity.create().connected(
        at: at,
        adopted: true,
      );

      expect(adopted.adopted, isTrue);
      expect(adopted.status, ConnectionStatus.connected);
    });

    test('leaving connected clears it, whichever way it is left', () {
      final adopted = ConnectionEntity.create().connected(
        at: at,
        adopted: true,
      );

      expect(adopted.disconnected().adopted, isFalse);
      expect(adopted.connecting().adopted, isFalse);
      expect(adopted.failed('tunnel_down').adopted, isFalse);
    });

    test('a dialled tunnel and an adopted one are not the same state', () {
      final dialled = ConnectionEntity.create().connected(at: at);
      final adopted = ConnectionEntity.create().connected(
        at: at,
        adopted: true,
      );

      expect(dialled, isNot(adopted));
      expect(dialled.hashCode, isNot(adopted.hashCode));
    });
  });

  // The regression this file exists for. Equality that ignored the status
  // made every transition look unchanged to Riverpod, which then told none of
  // the sixteen watch/listen sites reading connectionProvider. The status
  // still reached the screen, but only when something unrelated rebuilt it.
  group('a transition reaches the listeners', () {
    test('every status change is published', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = <ConnectionStatus>[];
      container.listen(
        _probeProvider,
        (_, next) => seen.add(next.status),
        fireImmediately: false,
      );

      final probe = container.read(_probeProvider.notifier)
        ..apply((state) => state.connecting())
        ..apply((state) => state.connected())
        ..apply((state) => state.disconnecting())
        ..apply((state) => state.disconnected());

      expect(seen, [
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
        ConnectionStatus.disconnecting,
        ConnectionStatus.ready,
      ]);
      expect(container.read(_probeProvider).status, ConnectionStatus.ready);
      expect(probe, isNotNull);
    });

    test('an error is published with its message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = <String?>[];
      container.listen(
        _probeProvider,
        (_, next) => seen.add(next.errorMessage),
      );

      container
          .read(_probeProvider.notifier)
          .apply((state) => state.failed('tunnel_down'));

      expect(seen, ['tunnel_down']);
    });

    test('a re-measured ping is published even at the same latency', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var notifications = 0;
      container.listen(_probeProvider, (_, _) => notifications++);

      // Stamped by hand: two `PingResult.success` calls in a row can read the
      // same instant off a coarse clock, as Windows' often does, and then the
      // second measurement really is the first.
      final measuredAt = DateTime.utc(2026, 1, 1, 12);
      PingResult ping200(DateTime at) =>
          PingResult(latencyMs: 200, isSuccessful: true, timestamp: at);

      final notifier = container.read(_probeProvider.notifier);
      notifier.apply((state) => state.withPingResult(ping200(measuredAt)));
      notifier.apply(
        (state) => state.withPingResult(
          ping200(measuredAt.add(const Duration(seconds: 1))),
        ),
      );

      // Two measurements, two notifications: the results carry different
      // timestamps, so the second is not the first.
      expect(notifications, 2);
    });

    test('republishing an unchanged state does not notify', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var notifications = 0;
      container.listen(_probeProvider, (_, _) => notifications++);

      final notifier = container.read(_probeProvider.notifier)
        ..apply((state) => state.connected());
      expect(notifications, 1);

      // A distinct object holding the same values. Widening the equality must
      // not have turned it into a source of pointless rebuilds.
      notifier.apply((state) => state.copyWith());

      expect(notifications, 1);
    });
  });
}
