import 'dart:async';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/modules/connection/di/connection_providers.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/presentation/controllers/engine_log_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../connection_test_doubles.dart';

void main() {
  late FakeEngineLogRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeEngineLogRepository();
    container = ProviderContainer(
      overrides: [engineLogRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  /// Opens the viewer and lets its first read land.
  Future<EngineLogNotifier> open() async {
    container.listen(engineLogProvider, (_, _) {});
    final notifier = container.read(engineLogProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  List<String> shown() => [
    for (final line in container.read(engineLogProvider).visible) line.message,
  ];

  test(
    'should read everything kept when it opens, then only what is new',
    () async {
      repository.queue([testLogLine('a'), testLogLine('b')]);
      final notifier = await open();
      expect(repository.reads.first, isTrue);
      expect(shown(), ['a', 'b']);

      repository.queue([testLogLine('c')]);
      await notifier.pollNow();
      expect(repository.reads.last, isFalse);
      expect(shown(), ['a', 'b', 'c']);
    },
  );

  test(
    'should ask the engine to hold every read after the first one',
    () async {
      repository.queue([testLogLine('a')]);
      await open();
      for (var i = 0; i < 20 && repository.waits.length < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(repository.waits.first, Duration.zero);
      expect(repository.waits[1], EngineLogNotifier.waitForLines);
    },
  );

  test('should not put back lines read before the log was cleared', () async {
    repository.queue([testLogLine('a')]);
    final notifier = await open();

    // A read is under way, holding a line the engine kept before the clear.
    final reading = Completer<void>();
    repository.readGate = reading;
    repository.queue([testLogLine('old')]);
    final poll = notifier.pollNow();
    await Future<void>.delayed(Duration.zero);

    expect(await notifier.clear(), isNull);
    reading.complete();
    await poll;

    expect(shown(), isEmpty);
  });

  test(
    'should keep the lines it has when the engine stops answering',
    () async {
      repository.queue([testLogLine('a')]);
      final notifier = await open();

      repository.batches.add(left(const EngineLogReadFailure('down')));
      await notifier.pollNow();
      final state = container.read(engineLogProvider);
      expect(state.unavailable, isTrue);
      expect(shown(), ['a']);

      repository.queue([testLogLine('b')]);
      await notifier.pollNow();
      expect(container.read(engineLogProvider).unavailable, isFalse);
      expect(shown(), ['a', 'b']);
    },
  );

  test('should show one component, and all of them again', () async {
    repository.queue([
      testLogLine('x', component: EngineLogComponent.xray),
      testLogLine('w', component: EngineLogComponent.warp),
    ]);
    final notifier = await open();

    notifier.showOnly(EngineLogComponent.warp);
    expect(shown(), ['w']);
    notifier.showOnly(null);
    expect(shown(), ['x', 'w']);
  });

  test('should hold no more lines than the engine keeps', () async {
    repository.queue([
      for (var i = 0; i < EngineLogNotifier.maxLines + 10; i++)
        testLogLine('$i'),
    ]);
    await open();
    final lines = shown();
    expect(lines.length, EngineLogNotifier.maxLines);
    expect(lines.first, '10');
  });

  test('should clear the engine and the screen', () async {
    repository.queue([testLogLine('a')], dropped: true);
    final notifier = await open();
    expect(container.read(engineLogProvider).dropped, isTrue);

    expect(await notifier.clear(), isNull);
    expect(repository.clears, 1);
    expect(shown(), isEmpty);
    expect(container.read(engineLogProvider).dropped, isFalse);
  });

  test('should keep the lines and name the key when clearing fails', () async {
    repository.queue([testLogLine('a')]);
    final notifier = await open();
    repository.clearResult = left(const EngineLogReadFailure('down'));

    expect(await notifier.clear(), UserFacingErrorKeys.engineLogUnavailable);
    expect(shown(), ['a']);
    expect(container.read(engineLogProvider).busy, isFalse);
  });

  test('should export what is on screen, filter included', () async {
    repository.queue([
      testLogLine('x', component: EngineLogComponent.xray),
      testLogLine('w', component: EngineLogComponent.warp),
    ]);
    final notifier = await open();
    notifier.showOnly(EngineLogComponent.xray);

    final result = await notifier.export();
    expect(result.outcome, EngineLogExportOutcome.shared);
    expect(repository.exported!.map((l) => l.message), ['x']);
  });

  test('should name the key when an export fails', () async {
    repository.exportResult = left(const EngineLogExportFailure('disk'));
    final notifier = await open();
    final result = await notifier.export();
    expect(result.failureKey, UserFacingErrorKeys.noStorageAccess);
    expect(container.read(engineLogProvider).busy, isFalse);
  });
}
