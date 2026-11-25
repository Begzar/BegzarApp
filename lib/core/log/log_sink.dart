import 'package:flutter/foundation.dart';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/log/log_palette.dart';

/// One line, before anything has decided how it looks.
///
/// A sink receives this rather than a formatted string so a test can assert on
/// the event and the fields without matching text, and so the formatting lives
/// in one place instead of at a hundred call sites.
@immutable
final class LogEntry {
  const LogEntry({
    required this.level,
    required this.domain,
    required this.event,
    required this.fields,
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String domain;
  final String event;
  final Map<String, Object?> fields;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Where log lines end up.
abstract interface class LogSink {
  void write(LogEntry entry);
}

/// Writes to the console, one line per entry.
///
/// `debugPrint` rather than `developer.log`: it is what shows in the terminal
/// during `flutter run` and in `adb logcat`, which is where anyone actually
/// looks. Both used to be called for every line — two copies of everything,
/// and because Flutter throttles one and not the other, the pair could
/// interleave out of order under load.
final class ConsoleLogSink implements LogSink {
  const ConsoleLogSink({this.palette = LogPalette.fromEnvironment});

  /// How the line is coloured. See [LogPalette] for what gets which hue, and
  /// for the dart-define that turns the whole thing off.
  final LogPalette palette;

  /// Wide enough for the domains in use, so events line up in a column and
  /// the eye can run down them.
  static const _domainWidth = 8;

  /// Same, for the event name. Past this a line just gets longer — the fields
  /// are still readable, they are only no longer aligned.
  static const _eventWidth = 26;

  @override
  void write(LogEntry entry) {
    debugPrint(format(entry, at: DateTime.now()));

    final stack = entry.stackTrace;
    if (stack != null) debugPrintStack(stackTrace: stack);
  }

  /// The line this sink would print, built rather than printed.
  ///
  /// Separate from [write] so a test can assert on the text without standing
  /// in front of `debugPrint`, and so the padding and the colour are decided
  /// in one place that can be read top to bottom.
  ///
  /// Padding is applied before colour, never after: an escape sequence is
  /// characters that occupy no width, so padding a painted string lines up the
  /// invisible parts and leaves the visible ones ragged.
  @visibleForTesting
  String format(LogEntry entry, {required DateTime at}) {
    final error = entry.error;

    // The event is padded so fields line up in a column, and only when there
    // is something to line up. Trimming it off afterwards would not work once
    // the event is painted: the padding then sits inside the colour, ahead of
    // the sequence that closes it, where `trimRight` cannot see it.
    final hasTail = entry.fields.isNotEmpty || error != null;
    final event = hasTail ? entry.event.padRight(_eventWidth) : entry.event;

    final line = StringBuffer()
      ..write(palette.faint(_clock(at)))
      ..write('  ')
      ..write(palette.domain(entry.domain.padRight(_domainWidth), entry.domain))
      ..write(palette.level(entry.level.glyph, entry.level))
      ..write(' ')
      ..write(palette.level(event, entry.level));

    entry.fields.forEach((key, value) {
      line
        ..write(' ')
        ..write(palette.faint('$key='))
        ..write(palette.fieldValue('$value', key, value));
    });

    if (error != null) {
      line
        ..write('  ')
        ..write(palette.faint('threw='))
        ..write(palette.thrown('$error'));
    }

    return line.toString();
  }

  /// `HH:mm:ss.mmm`. The date is never the question — how long something took,
  /// and what happened just before it, always is.
  static String _clock(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

/// Keeps entries instead of printing them.
///
/// For tests: install one, run the code, and assert on what it collected.
/// Installing it also silences a suite that would otherwise print several
/// hundred lines of traces belonging to whatever it happened to exercise.
final class RecordingLogSink implements LogSink {
  final List<LogEntry> entries = [];

  @override
  void write(LogEntry entry) => entries.add(entry);

  /// The events seen so far, in order — usually the whole assertion.
  List<String> get events => [for (final e in entries) e.event];

  /// Entries at [level] and above, which is how a test asks "did anything go
  /// wrong" without naming what.
  List<LogEntry> atLeast(LogLevel level) =>
      [for (final e in entries) if (e.level.index >= level.index) e];
}
