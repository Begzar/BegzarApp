/// The part of the engine a log line came from.
enum EngineLogComponent {
  xray,
  warp,
  engine;

  /// Reads the engine's name for a component. An unknown one is the engine's
  /// own, so a component added later still shows.
  static EngineLogComponent fromName(String name) {
    for (final component in values) {
      if (component.name == name) return component;
    }
    return engine;
  }
}

/// How severe a log line is, least first.
enum EngineLogLevel {
  debug,
  info,
  warn,
  error;

  static EngineLogLevel fromName(String name) {
    for (final level in values) {
      if (level.name == name) return level;
    }
    return info;
  }
}

/// One line of the engine log, as the log viewer shows it.
///
/// The engine redacted the message before keeping it: no share link, key,
/// server name or public address reaches this type, so it can be shown and
/// exported as it is.
class EngineLogLine {
  const EngineLogLine({
    required this.time,
    required this.component,
    required this.level,
    required this.message,
    required this.fromTunnel,
  });

  final DateTime time;
  final EngineLogComponent component;
  final EngineLogLevel level;
  final String message;

  /// The line came from the packet tunnel's process rather than the app's.
  /// Only Apple runs the tunnel's engine apart.
  final bool fromTunnel;

  /// The line as it is exported: time, component, level and message.
  String toExportText() {
    final where = fromTunnel ? '${component.name}@tunnel' : component.name;
    return '${_clock(time)} $where ${level.name.toUpperCase()} $message';
  }

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms';
  }
}

/// What one read of the engine log brought.
class EngineLogBatch {
  const EngineLogBatch({required this.lines, required this.dropped});

  static const empty = EngineLogBatch(lines: [], dropped: false);

  /// The lines since the last read, oldest first.
  final List<EngineLogLine> lines;

  /// Lines were pushed out of the engine's ring before they were read.
  final bool dropped;
}

/// The text an export writes: a header saying what the file is, then one line
/// per entry.
String engineLogExportText(
  Iterable<EngineLogLine> lines, {
  required DateTime exportedAt,
  required String appVersion,
}) {
  final buffer = StringBuffer()
    ..writeln('Begzar engine log')
    ..writeln('App version: $appVersion')
    ..writeln('Exported: ${exportedAt.toIso8601String()}')
    ..writeln('Every line was redacted by the engine before it was kept.')
    ..writeln();
  for (final line in lines) {
    buffer.writeln(line.toExportText());
  }
  return buffer.toString();
}

/// What became of an export.
enum EngineLogExportOutcome {
  /// Handed to the share sheet and sent somewhere.
  shared,

  /// Written to a file the user picked, or to Downloads.
  saved,

  /// The user closed the share sheet or the save dialog.
  cancelled,
}

/// The name an exported log is offered under, stamped with when it was made,
/// so two exports never overwrite each other.
String engineLogFileName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'begzar-engine-log-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}.txt';
}
