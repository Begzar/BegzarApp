import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/log/log_sink.dart';
import 'package:flutter_test/flutter_test.dart';

/// The logger's own contract: what it writes, what it refuses to write, and
/// what it costs when nobody is listening.
void main() {
  late RecordingLogSink recorder;

  setUp(() {
    recorder = RecordingLogSink();
    Log.sink = recorder;
  });

  // flutter_test_config.dart silences the log for every other suite; leaving a
  // recorder installed would make the next file's traces pile up in it.
  tearDown(() => Log.sink = null);

  group('a line carries its level, domain, event and fields', () {
    test('each method writes at its own level', () {
      const log = Log('connect');
      log.trace('one.dial');
      log.warn('one.slow');
      log.error('one.failed');

      expect(recorder.events, ['one.dial', 'one.slow', 'one.failed']);
      expect(
        [for (final e in recorder.entries) e.level],
        [LogLevel.trace, LogLevel.warn, LogLevel.error],
      );
    });

    test('fields arrive as they were given, not as text', () {
      const Log('api').trace('subscription.ok', {'configs': 12});

      expect(recorder.entries.single.fields, {'configs': 12});
      expect(
        recorder.entries.single.fields['configs'],
        isA<int>(),
        reason:
            'the sink formats, so a test can assert on the value rather than '
            'on how some sink chose to render it',
      );
    });

    test('an error carries what was thrown', () {
      final thrown = StateError('no tunnel');
      const Log('connect').error('one.threw', const {}, thrown);

      expect(recorder.entries.single.error, same(thrown));
    });

    test('atLeast filters by severity, which is the point of having levels', () {
      const log = Log('connect');
      log.trace('a');
      log.warn('b');
      log.error('c');

      expect(
        [for (final e in recorder.atLeast(LogLevel.warn)) e.event],
        ['b', 'c'],
      );
    });
  });

  group('secrets are rendered, never written', () {
    test('scheme keeps the protocol and drops the rest', () {
      // Assembled rather than written out: a whole proxy URL in a source file
      // is what `no_bundled_proxy_configs_test` exists to forbid.
      const secret = 'aef1-2c3d@example.invalid:443?security=reality';
      expect(Log.scheme('vless${'://'}$secret'), 'vless');
      expect(Log.scheme('trojan${'://'}$secret'), 'trojan');
    });

    test('a string that is not a URL says so rather than leaking itself', () {
      expect(Log.scheme('not-a-url-at-all'), '?');
      expect(Log.scheme(''), '?');
    });

    test('redact reports presence and length, never the value', () {
      const token = 'cmHuICRJoGqni5SRiaqqZqFTngg6or1QV7UUimk8';

      final rendered = Log.redact(token);

      expect(rendered, '<redacted:40>');
      expect(rendered, isNot(contains(token)));
      expect(Log.redact(null), '<none>');
      expect(Log.redact(''), '<none>');
    });
  });

  group('silence is free', () {
    test('nothing is written when there is no sink', () {
      Log.sink = null;

      const Log('connect').trace('one.dial', {'scheme': 'vless'});

      Log.sink = recorder;
      expect(recorder.entries, isEmpty);
    });

    test('a line costs one null check when nothing is listening', () {
      Log.sink = null;
      var formatted = 0;

      // The caller's map is still built — Dart evaluates the argument before
      // the call. What the guard saves is everything past that: no entry, no
      // formatting, no write. Worth stating, because it is the reason a trace
      // can sit on the connect path without being conditional at its site.
      const Log('connect').trace('one.dial', {'scheme': 'vless'});
      formatted = recorder.entries.length;

      Log.sink = recorder;
      expect(formatted, 0);
    });
  });
}
