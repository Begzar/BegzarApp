import 'package:flutter/foundation.dart';

import 'package:begzar/core/log/log_sink.dart';

/// How much a line is worth stopping for.
///
/// Ordered, so a sink can drop everything under a floor. The reason this
/// exists at all: a trace and a failure used to be the same line, and once
/// there are a hundred of them, "what went wrong" is not a question the log
/// can answer.
enum LogLevel {
  /// The ordinary steps of an operation. Most lines are these.
  trace,

  /// Something worth noticing that is not a fault — a retry, a fallback taken.
  warn,

  /// The operation did not do what it was asked to.
  error;

  /// One character, so the level is visible without reading the words.
  String get glyph => switch (this) {
    LogLevel.trace => '·',
    LogLevel.warn => '!',
    LogLevel.error => 'x',
  };
}

/// A named log for one area of the app.
///
/// Declared once per class that logs, beside the thing it describes:
///
/// ```dart
/// class ConnectionService {
///   static const _log = Log('connect');
/// }
/// ```
///
/// Nothing is written outside a debug build. [sink] is null in release and
/// every method returns before it touches its arguments, so a line costs a
/// null check and the fields are never even built.
///
/// ## What may go in a line
///
/// Shapes, not values: a type, a count, an enum, a status code, a duration.
/// Never a config URL, a token, an access key, a password, or a real user's
/// address. This is not a convention to remember — it is checked by
/// `test/architecture/logging_discipline_test.dart`, which reads every call
/// site in every package and fails the suite on a field that looks like a
/// secret. [scheme] and [redact] exist so the safe rendering is the easy one.
@immutable
final class Log {
  const Log(this.domain);

  /// What this log is about — `connect`, `api`, `premium`. Shown on every
  /// line, and what you filter by when only one area is interesting.
  final String domain;

  /// Where lines go. Null in release, so nothing is written and nothing is
  /// built to write.
  ///
  /// A test replaces this to assert on what was logged, or to silence a suite
  /// that would otherwise print a few hundred lines of someone else's traces.
  static LogSink? sink = kDebugMode ? const ConsoleLogSink() : null;

  /// An ordinary step. `event` is a dotted name — `connect.dial`,
  /// `subscription.fetch` — so a log can be grepped for one operation across
  /// the run rather than read in order.
  void trace(String event, [Map<String, Object?> fields = const {}]) =>
      _write(LogLevel.trace, event, fields, null, null);

  /// Worth noticing, but the operation carried on: a retry, a fallback, a
  /// cache that had gone cold.
  void warn(String event, [Map<String, Object?> fields = const {}]) =>
      _write(LogLevel.warn, event, fields, null, null);

  /// The operation failed. [error] and [stackTrace] are for a `catch` that has
  /// them; a failure that is a value rather than a throw belongs in [fields]
  /// as its type and its user-facing key.
  void error(
    String event, [
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  ]) => _write(LogLevel.error, event, fields, error, stackTrace);

  void _write(
    LogLevel level,
    String event,
    Map<String, Object?> fields,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final target = sink;
    if (target == null) return;
    target.write(
      LogEntry(
        level: level,
        domain: domain,
        event: event,
        fields: fields,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// The scheme of a proxy URL, and nothing else.
  ///
  /// The rest of that string is a credential: a proxy URL carries the id and
  /// the host that make it work, which is why the whole thing may never be
  /// written down. Which protocol was dialled is the part worth knowing, and
  /// it is all this returns.
  static String scheme(String url) {
    final end = url.indexOf('://');
    return end <= 0 ? '?' : url.substring(0, end);
  }

  /// Says that a secret was present and how long it was, never what it was.
  ///
  /// For the case where the question is "did we have a token at all" — which
  /// a length answers and the value does not.
  static String redact(String? secret) =>
      secret == null || secret.isEmpty ? '<none>' : '<redacted:${secret.length}>';
}
