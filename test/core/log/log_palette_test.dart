import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/log/log_palette.dart';
import 'package:begzar/core/log/log_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_sources.dart';

/// What a console line looks like, painted and not.
///
/// The sink's own contract, asserted on the string it would print rather than
/// on what reached the terminal — `format` exists so this is possible without
/// standing in front of `debugPrint`.
void main() {
  final at = DateTime(2026, 9, 5, 20, 7, 58, 294);

  LogEntry entry({
    LogLevel level = LogLevel.trace,
    String domain = 'api',
    String event = 'response',
    Map<String, Object?> fields = const {},
    Object? error,
  }) => LogEntry(
    level: level,
    domain: domain,
    event: event,
    fields: fields,
    error: error,
  );

  String plain(LogEntry e) =>
      const ConsoleLogSink(palette: LogPalette.plain).format(e, at: at);

  String painted(LogEntry e) => const ConsoleLogSink(
    palette: LogPalette(enabled: true),
  ).format(e, at: at);

  group('the line says the same thing either way', () {
    test('an unpainted line carries no escapes at all', () {
      final line = plain(
        entry(fields: const {'status': 200, 'elapsed': '112ms'}),
      );

      expect(line, isNot(contains('\x1B')));
      expect(line, startsWith('20:07:58.294  api'));
      expect(line, contains('status=200'));
      expect(line, contains('elapsed=112ms'));
    });

    test('painting adds colour and changes nothing else', () {
      const e = LogEntry(
        level: LogLevel.trace,
        domain: 'api',
        event: 'response',
        fields: {'status': 200},
      );

      expect(_stripAnsi(painted(e)), plain(e));
    });

    test('every sequence opened is closed', () {
      final line = painted(
        entry(
          level: LogLevel.error,
          fields: const {'status': 503},
          error: StateError('no tunnel'),
        ),
      );

      expect(
        '\x1B['.allMatches(line).length,
        _resetCount(line) * 2,
        reason: 'each painted run is one opening sequence and one reset',
      );
    });
  });

  group('a domain keeps its hue', () {
    test('the same domain paints the same, every time', () {
      const palette = LogPalette(enabled: true);

      expect(palette.domain('api', 'api'), palette.domain('api', 'api'));
    });

    // The regression this group exists for. Summing code units put `api`,
    // `connect` and `tunnel` on one magenta, which made three of the busiest
    // streams in the log indistinguishable — the exact thing the hue is for.
    test('no two domains in use share a colour', () {
      const palette = LogPalette(enabled: true);
      final domains = _domainsInSource();

      // Without this the assertion below passes on an empty set, which is what
      // a broken scan looks like.
      expect(
        domains,
        isNotEmpty,
        reason: 'the scan found no Log declarations at all',
      );

      final inks = {for (final d in domains) _inkOf(palette.domain(d, d))};

      expect(
        inks.length,
        domains.length,
        reason:
            'every domain the app logs under must be told apart by hue; '
            'found $domains',
      );
    });

    test('a domain nobody registered is still given a colour', () {
      const palette = LogPalette(enabled: true);

      expect(_inkOf(palette.domain('brandnew', 'brandnew')), isNotNull);
    });

    // Yellow and red mean warn and error everywhere else on the line. A domain
    // that landed on either would make all of its traces read as failures.
    test('no domain lands on a level colour', () {
      const palette = LogPalette(enabled: true);

      for (final domain in _domainsInSource()) {
        expect(
          _inkOf(palette.domain(domain, domain)),
          isNot(anyOf('33', '31')),
          reason: '$domain must not be painted warn or error',
        );
      }
    });
  });

  group('severity outranks the stream it belongs to', () {
    test('a trace is left alone, because most lines are traces', () {
      const palette = LogPalette(enabled: true);

      expect(
        palette.level('subscription.ok', LogLevel.trace),
        'subscription.ok',
      );
    });

    test('a warn and an error are painted apart', () {
      const palette = LogPalette(enabled: true);

      expect(_inkOf(palette.level('x', LogLevel.warn)), '33');
      expect(_inkOf(palette.level('x', LogLevel.error)), '31');
    });
  });

  group('a status is read as a verdict', () {
    const palette = LogPalette(enabled: true);

    test('2xx, 4xx and 5xx are told apart', () {
      expect(_inkOf(palette.fieldValue('200', 'status', 200)), '32');
      expect(_inkOf(palette.fieldValue('429', 'status', 429)), '33');
      expect(_inkOf(palette.fieldValue('503', 'status', 503)), '31');
    });

    test('any other field is left plain', () {
      expect(palette.fieldValue('112ms', 'elapsed', '112ms'), '112ms');
      expect(palette.fieldValue('vless', 'scheme', 'vless'), 'vless');
    });

    test('a status that is not a number is not guessed at', () {
      expect(palette.fieldValue('?', 'status', '?'), '?');
      expect(palette.fieldValue('null', 'status', null), 'null');
    });
  });

  group('padding lines the column up without trailing it', () {
    test('an event with fields is padded so values start together', () {
      final short = plain(entry(event: 'ok', fields: const {'a': 1}));
      final long = plain(
        entry(event: 'subscription.ok', fields: const {'a': 1}),
      );

      expect(short.indexOf('a=1'), long.indexOf('a=1'));
    });

    test('an event with nothing after it carries no padding', () {
      expect(plain(entry(event: 'request')), endsWith('request'));
      expect(painted(entry(event: 'request')), endsWith('request'));
    });
  });
}

/// Every domain the app actually logs under, read out of the source rather
/// than listed here.
///
/// A list written down in a test is a list that rots: the domain added next
/// month would collide with an existing colour and nothing would say so. The
/// same bargain `logging_discipline_test.dart` makes, for the same reason.
Set<String> _domainsInSource() {
  final declaration = RegExp(r"""Log\(\s*'([A-Za-z][A-Za-z0-9_]*)'""");
  final found = <String>{};

  for (final source in dartSourcesUnder('lib')) {
    for (final match in declaration.allMatches(source.readAsStringSync())) {
      found.add(match.group(1)!);
    }
  }
  return found;
}

/// The colour code a painted string opens with, or null when it is unpainted.
String? _inkOf(String painted) {
  final match = RegExp(r'^\x1B\[(\d+)m').firstMatch(painted);
  return match?.group(1);
}

String _stripAnsi(String text) => text.replaceAll(RegExp(r'\x1B\[\d+m'), '');

int _resetCount(String text) => RegExp(r'\x1B\[0m').allMatches(text).length;
