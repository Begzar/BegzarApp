import 'dart:ui';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/modules/connection/data/datasources/engine_log_data_source.dart';
import 'package:begzar/modules/connection/data/datasources/engine_log_exporter.dart';
import 'package:begzar/modules/connection/data/repositories/engine_log_repository.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:begzar_engine/begzar_engine.dart';

class _RecordingExporter implements EngineLogExporter {
  String? text;
  String? fileName;
  Object? throwing;

  @override
  Future<EngineLogExportOutcome> export(
    String text, {
    required String fileName,
    Rect? shareOrigin,
  }) async {
    if (throwing != null) throw throwing!;
    this.text = text;
    this.fileName = fileName;
    return EngineLogExportOutcome.saved;
  }
}

EngineLogEntry _entry(int seq, String message, {String source = 'xray'}) {
  return EngineLogEntry(
    seq: seq,
    time: DateTime(2026, 1, 1, 0, 0, seq),
    source: source,
    level: 'warn',
    message: message,
    process: EngineLogProcess.tunnel,
  );
}

void main() {
  late List<EngineLogCursor> cursors;
  late List<EngineLogPage> pages;
  late Object? readThrows;
  late _RecordingExporter exporter;
  late EngineLogRepository repository;

  setUp(() {
    cursors = [];
    pages = [];
    readThrows = null;
    exporter = _RecordingExporter();
    repository = EngineLogRepository(
      EngineLogDataSource(
        readPage: (cursor, wait) async {
          cursors.add(cursor);
          if (readThrows != null) throw readThrows!;
          return pages.removeAt(0);
        },
        clearAll: () async {},
      ),
      exporter,
      appVersion: () async => '8.0.4+38',
      clock: () => DateTime(2026, 11, 9, 8, 7, 6),
    );
  });

  EngineLogPage page(List<EngineLogEntry> entries, {bool dropped = false}) {
    var cursor = EngineLogCursor.start;
    if (entries.isNotEmpty) {
      cursor = cursor.advanced(
        EngineLogProcess.tunnel,
        EngineLogChunk(
          entries: entries,
          next: entries.last.seq,
          epoch: 'e',
          dropped: dropped,
        ),
      );
    }
    return EngineLogPage(entries: entries, cursor: cursor, dropped: dropped);
  }

  test('should map each entry and carry the cursor to the next read', () async {
    pages.add(page([_entry(1, 'dial <ip>:443', source: 'warp')]));
    pages.add(page([]));

    final first = (await repository.read()).getOrElse((_) => throw 'left');
    final line = first.lines.single;
    expect(line.component, EngineLogComponent.warp);
    expect(line.level, EngineLogLevel.warn);
    expect(line.fromTunnel, isTrue);
    expect(line.message, 'dial <ip>:443');

    await repository.read();
    expect(cursors.last.afterIn(EngineLogProcess.tunnel), 1);
  });

  test('should start over when asked to read from the start', () async {
    pages.add(page([_entry(1, 'a')]));
    pages.add(page([_entry(1, 'a')]));
    await repository.read();
    await repository.read(fromStart: true);
    expect(cursors.last.afterIn(EngineLogProcess.tunnel), 0);
  });

  test('should report an engine that did not answer by its key', () async {
    readThrows = BegzarEngineException('connection refused to 203.0.113.9');
    final result = await repository.read();

    final failure = result.getLeft().toNullable()!;
    expect(failure, isA<EngineLogReadFailure>());
    expect(failure.userFacingKey, UserFacingErrorKeys.engineLogUnavailable);
    // The engine's prose stays out of the failure.
    expect(failure.message, isNot(contains('203.0.113.9')));
  });

  test('should export the lines under a stamped name with a header', () async {
    final lines = [
      EngineLogLine(
        time: DateTime(2026, 11, 9, 8),
        component: EngineLogComponent.xray,
        level: EngineLogLevel.error,
        message: 'handshake failed',
        fromTunnel: false,
      ),
    ];
    final result = await repository.export(lines);

    expect(result.toNullable(), EngineLogExportOutcome.saved);
    expect(exporter.fileName, 'begzar-engine-log-20261109-080706.txt');
    expect(exporter.text, contains('App version: 8.0.4+38'));
    expect(exporter.text, contains('xray ERROR handshake failed'));
  });

  test('should report a file that could not be written', () async {
    exporter.throwing = const FileSystemFailureForTest();
    final result = await repository.export(const []);
    final failure = result.getLeft().toNullable()!;
    expect(failure, isA<EngineLogExportFailure>());
    expect(failure.userFacingKey, UserFacingErrorKeys.noStorageAccess);
  });
}

class FileSystemFailureForTest implements Exception {
  const FileSystemFailureForTest();
}
