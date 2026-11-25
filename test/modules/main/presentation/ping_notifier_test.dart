import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/ping_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../connection/connection_test_doubles.dart';

void main() {
  late FakeConnectionRepository connections;
  late ProviderContainer container;

  /// Wires the real controller graph to a fake repository, so the test drives
  /// the same path the pill does.
  void buildContainer() {
    container = ProviderContainer(
      overrides: [connectionRepositoryProvider.overrideWithValue(connections)],
    );
    addTearDown(container.dispose);
  }

  test('nothing measured yet reads as no value rather than zero', () {
    connections = FakeConnectionRepository();
    buildContainer();

    expect(container.read(pingProvider), const AsyncValue<int?>.data(null));
  });

  test('a successful measurement publishes its latency', () async {
    connections = FakeConnectionRepository(pingResult: PingResult.success(312));
    buildContainer();

    await container.read(pingProvider.notifier).measure();

    expect(container.read(pingProvider).value, 312);
    expect(container.read(pingProvider).hasError, isFalse);
  });

  test('a failed measurement becomes an error, not a latency', () async {
    connections = FakeConnectionRepository(
      pingResult: PingResult.failure('unreachable'),
    );
    buildContainer();

    await container.read(pingProvider.notifier).measure();

    final state = container.read(pingProvider);
    expect(state.hasError, isTrue);
    expect(state.error, 'unreachable');
  });

  // The measurement goes through the connection controller rather than around
  // it, so the result it reports is also the one on the connection state.
  test('the connection state carries the same reading', () async {
    connections = FakeConnectionRepository(pingResult: PingResult.success(88));
    buildContainer();

    await container.read(pingProvider.notifier).measure();

    expect(container.read(connectionProvider).lastPingResult?.latencyMs, 88);
  });

  test('measuring reports loading before it reports a value', () async {
    connections = FakeConnectionRepository(pingResult: PingResult.success(120));
    buildContainer();

    final seen = <bool>[];
    container.listen(pingProvider, (_, next) => seen.add(next.isLoading));

    await container.read(pingProvider.notifier).measure();

    expect(seen.first, isTrue);
    expect(seen.last, isFalse);
  });
}
