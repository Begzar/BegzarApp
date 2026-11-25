import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// Reads one page of the engine log after a cursor, holding the read up to
/// the wait when nothing is new.
typedef EngineLogPageReader =
    Future<EngineLogPage> Function(EngineLogCursor cursor, Duration wait);

/// The engine log, read through the proxy engine.
///
/// Holds where the last read left off, so each read brings only what is new.
/// Every line arrives redacted: the engine strips links, keys, servers and
/// public addresses before it keeps a line.
class EngineLogDataSource {
  EngineLogDataSource({
    EngineLogPageReader? readPage,
    Future<void> Function()? clearAll,
  }) : _readPage = readPage ?? BegzarEngine.ins.readEngineLog,
       _clearAll = clearAll ?? BegzarEngine.ins.clearEngineLog;

  final EngineLogPageReader _readPage;
  final Future<void> Function() _clearAll;
  EngineLogCursor _cursor = EngineLogCursor.start;

  /// The lines since the last read, or since the oldest kept with
  /// [fromStart]. With [wait], a read that finds nothing new is held until a
  /// line arrives. Throws when the engine could not be reached.
  Future<EngineLogBatch> read({
    bool fromStart = false,
    Duration wait = Duration.zero,
  }) async {
    if (fromStart) _cursor = EngineLogCursor.start;
    final page = await _readPage(_cursor, wait);
    _cursor = page.cursor;
    return EngineLogBatch(
      lines: [for (final entry in page.entries) _lineOf(entry)],
      dropped: page.dropped,
    );
  }

  /// Empties the log in every process that keeps one.
  Future<void> clear() async {
    await _clearAll();
    _cursor = EngineLogCursor.start;
  }

  static EngineLogLine _lineOf(EngineLogEntry entry) {
    return EngineLogLine(
      time: entry.time,
      component: EngineLogComponent.fromName(entry.source),
      level: EngineLogLevel.fromName(entry.level),
      message: entry.message,
      fromTunnel: entry.process == EngineLogProcess.tunnel,
    );
  }
}
