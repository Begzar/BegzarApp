import 'package:begzar/core/log/log.dart';

/// Colour for console log lines, and the rules about what gets which.
///
/// A debug run prints a few hundred lines from half a dozen unrelated areas.
/// Read as one column of grey they are a wall; the eye has to parse each line
/// to find out whether it is about the tunnel, an HTTP call, or the ad gate.
/// Colour answers that before the words are read, on two axes:
///
/// - **What area** — each domain keeps one hue for the whole run, so `api`
///   lines read as one stream down the page and `connect` as another.
/// - **How much it matters** — the level paints the glyph and the event, so a
///   failure stands out of its own stream without leaving it.
///
/// Everything structural — the clock, the `=` between a field and its value —
/// is faint, because it is never what anyone is looking for.
///
/// ## Where the colour is legible
///
/// ANSI renders in the terminal running `flutter run`, and prints as raw
/// escape sequences in a plain `adb logcat`. Nothing can tell those apart from
/// inside the app: on Android its stdout is not a terminal, so a
/// `supportsAnsiEscapes` check answers "no" even when `flutter run` would
/// render the colour perfectly. So this is a switch rather than a detection —
/// on by default, because `flutter run` is where the log is normally read:
///
/// ```
/// flutter run --dart-define=BEGZAR_LOG_COLOR=false
/// ```
final class LogPalette {
  const LogPalette({required this.enabled});

  /// What the build was told, honoured unless a caller asks for otherwise.
  static const LogPalette fromEnvironment = LogPalette(enabled: _defined);

  /// For a test, and for anywhere the escapes would be noise rather than help.
  static const LogPalette plain = LogPalette(enabled: false);

  static const String defineKey = 'BEGZAR_LOG_COLOR';

  static const bool _defined = bool.fromEnvironment(
    defineKey,
    defaultValue: true,
  );

  final bool enabled;

  /// Structure rather than content: the clock, and the `key=` of a field.
  String faint(String text) => _paint(text, _faint);

  /// One hue per domain, held for the life of the run.
  String domain(String text, String domain) =>
      _paint(text, _domainInks[_hue(domain)]);

  /// The level glyph and the event name. A trace is left alone — most lines
  /// are traces, and colouring them all would say nothing about any of them.
  String level(String text, LogLevel level) => switch (level) {
    LogLevel.trace => text,
    LogLevel.warn => _paint(text, _yellow),
    LogLevel.error => _paint(text, _red),
  };

  /// A field's value.
  ///
  /// Most are left plain, so the ones that are not stand out. The exception is
  /// a field whose value is a verdict rather than a measurement — `status`,
  /// which is what anyone reading a request/response pair is looking for. It
  /// is a convention about the field's *name*, so the sink can honour it
  /// without knowing which module wrote the line.
  String fieldValue(String text, String key, Object? value) {
    if (key != _statusKey || value is! int) return text;
    return _paint(text, switch (value) {
      >= 200 && < 300 => _green,
      >= 400 && < 500 => _yellow,
      >= 500 => _red,
      _ => _faint,
    });
  }

  /// What a `catch` handed over, which is always the worst news on the line.
  String thrown(String text) => _paint(text, _red);

  String _paint(String text, String ink) =>
      enabled ? '$_csi${ink}m$text$_csi${_reset}m' : text;

  /// Which hue a domain gets.
  ///
  /// The domains in use are listed, and take their ink by position. That is
  /// worth a list to maintain because hashing them does not work: summing the
  /// code units of the six real domains put `api`, `connect` and `tunnel` on
  /// the same colour, which is the one outcome the hue exists to prevent, and
  /// any other hash is the same gamble with different odds.
  ///
  /// A domain not listed here falls back to that hash, so a new one is
  /// coloured without being registered first — add it to the list when it
  /// collides with something.
  static int _hue(String domain) {
    final known = _domainOrder.indexOf(domain);
    if (known >= 0) return known % _domainInks.length;

    var sum = 0;
    for (final unit in domain.codeUnits) {
      sum += unit;
    }
    return sum % _domainInks.length;
  }

  /// Every domain the app logs under, in the order they take their hue.
  ///
  /// Longer than [_domainInks] would mean the tail wraps back onto colours
  /// already in use; keep the list at or under that length, or widen the
  /// palette with a hue that is neither yellow nor red.
  static const List<String> _domainOrder = [
    'api',
    'connect',
    'premium',
    'tunnel',
    'engine',
    'adgate',
  ];

  /// The hues a domain can land on.
  ///
  /// Yellow and red are deliberately absent: they mean "warn" and "error"
  /// everywhere else on the line, and a domain that happened to be red would
  /// make every one of its traces look like a failure.
  static const List<String> _domainInks = [
    _cyan,
    _green,
    _magenta,
    _blue,
    _brightCyan,
    _brightMagenta,
  ];

  /// The field name whose value is read as a verdict. See [fieldValue].
  static const String _statusKey = 'status';

  static const String _csi = '\x1B[';
  static const String _reset = '0';
  static const String _faint = '2';
  static const String _red = '31';
  static const String _green = '32';
  static const String _yellow = '33';
  static const String _blue = '34';
  static const String _magenta = '35';
  static const String _cyan = '36';
  static const String _brightMagenta = '95';
  static const String _brightCyan = '96';
}
