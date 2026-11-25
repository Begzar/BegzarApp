// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// The process an engine log line came from.
///
/// On Android, Windows and Linux the engine runs in the app, so every line is
/// [app]. On iOS and macOS the tunnel's engine runs in the packet tunnel,
/// which keeps a log of its own while it runs; the app's in-process probes
/// and config builds log to [app].
enum EngineLogProcess { app, tunnel }

/// One line of the engine log. The engine redacted it before keeping it, so
/// it carries no link, key, server or user address.
class EngineLogEntry {
  const EngineLogEntry({
    required this.seq,
    required this.time,
    required this.source,
    required this.level,
    required this.message,
    required this.process,
  });

  /// Numbered within its process's log; only grows until the log is cleared
  /// or the process restarts.
  final int seq;
  final DateTime time;

  /// `xray`, `warp` or `engine`.
  final String source;

  /// `debug`, `info`, `warn` or `error`.
  final String level;
  final String message;
  final EngineLogProcess process;
}

/// What one process's log returned for one read.
class EngineLogChunk {
  const EngineLogChunk({
    required this.entries,
    required this.next,
    required this.epoch,
    required this.dropped,
  });
  final List<EngineLogEntry> entries;
  final int next;
  final String epoch;
  final bool dropped;
}

/// Where a reader is in each process's log. Start from [start] and pass back
/// the cursor each [EngineLogPage] returns.
class EngineLogCursor {
  const EngineLogCursor._(this._positions);

  static const start = EngineLogCursor._({});

  final Map<EngineLogProcess, ({String epoch, int next})> _positions;

  /// The seq to read after in [process]'s log.
  int afterIn(EngineLogProcess process) => _positions[process]?.next ?? 0;

  /// The epoch last seen from [process], or null before the first read.
  String? epochOf(EngineLogProcess process) => _positions[process]?.epoch;

  EngineLogCursor advanced(EngineLogProcess process, EngineLogChunk chunk) {
    return EngineLogCursor._({
      ..._positions,
      process: (epoch: chunk.epoch, next: chunk.next),
    });
  }
}

/// The lines every process logged since the cursor, in time order.
class EngineLogPage {
  const EngineLogPage({
    required this.entries,
    required this.cursor,
    required this.dropped,
  });

  final List<EngineLogEntry> entries;
  final EngineLogCursor cursor;

  /// Some lines were pushed out of a log before they were read.
  final bool dropped;
}
