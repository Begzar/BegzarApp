import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_sources.dart';

/// Enforces how this codebase is allowed to log.
///
/// The rules used to live in a doc comment on the logger — *never call this
/// with configs, tokens, hosts, or session data* — and a comment stopped
/// nobody. When someone needed to print an access key they wrote a second
/// logger beside the first, with its own debug guard and none of the rule, and
/// a live premium credential went into `adb logcat` on every debug run until
/// it was found by reading the device's log by hand.
///
/// That is the failure this file exists to make impossible. It reads every
/// Dart source in every package and fails the suite on the three shapes that
/// let it happen: writing to the console without going through [Log], adding a
/// second logger, and naming a secret in a log line.
///
/// It is the same bargain `layer_boundaries_test.dart` makes, for the same
/// reason: a rule that only a person can enforce is a rule that holds until
/// the first hurry.
class _LogRule {
  const _LogRule({
    required this.name,
    required this.matches,
    required this.why,
  });

  final String name;

  /// The offending fragment in a line of source, or null when it is clean.
  final String? Function(String line) matches;

  /// Printed when the rule fires, so the failure explains itself rather than
  /// pointing at a line number and leaving the reader to guess.
  final String why;
}

/// Every package in the workspace. A rule that only covered `lib/` is how the
/// Dart config parser, since replaced by the engine's own, came to have a
/// logger of its own that printed whole `vless://` URLs.
const _packageRoots = <String>['lib', 'engine_stub/lib'];

/// The private engine, checked only where it is checked out: the public
/// repository has the stand-in alone.
const _enginePackageRoot = 'begzar-engine/lib';

/// Generated bindings and the logger's own implementation, which is the one
/// place allowed to reach the console.
bool _exempt(String path) =>
    path.contains('/gen/') ||
    path.endsWith('lib/core/log/log_sink.dart') ||
    path.endsWith('lib/core/log/log.dart');

/// Writing to the console outside the sink.
///
/// Matched on the call rather than the import: `debugPrint` is exported by
/// `package:flutter/material.dart` too, so an import list cannot see it.
final _consoleCall = RegExp(
  r'(^|[^\w.])(print|debugPrint|debugPrintStack)\s*\(|developer\s*\.\s*log\s*\(',
);

/// A second logger. The point of one is that there is one: two of them means
/// two sets of rules, and the weaker set is the one that leaks.
final _rivalLogger = RegExp(r'\bclass\s+\w*Log(ger)?\b');

/// Identifiers whose value may never be written down.
///
/// A proxy URL carries the id and host that make it work; a token, key or
/// password is the credential itself. `Log.scheme` and `Log.redact` exist so
/// the useful part of each can still be logged.
const _secretNames = <String>[
  'url',
  'uri',
  'token',
  'key',
  'secret',
  'password',
  'credential',
  'accessKey',
  'access_key',
  'sessionToken',
  'config.url',
];

/// A log call that interpolates one of [_secretNames].
///
/// Deliberately blunt: it fires on the identifier's name, not on what the
/// value turns out to be at run time, because the name is what a reader and a
/// reviewer see. A field genuinely holding something safe is renamed or passed
/// through `Log.scheme`; there is no exception list, because an exception list
/// is where this kind of rule goes to die.
String? _secretInLogCall(String line) {
  if (!RegExp(r'\.(trace|warn|error)\s*\(').hasMatch(line)) return null;
  for (final name in _secretNames) {
    // `$url`, `${config.url}`, `'url': url` — any mention inside the call.
    final escaped = RegExp.escape(name);
    final mention = RegExp(
      // `$url` and `${config.url}` — interpolated straight into a message.
      r'\$\{?[\w.]*\b$escaped\b'
      // `'url': whatever` — named as a structured field.
      '''|['"]$escaped['"]\\s*:''',
      caseSensitive: false,
    );
    final hit = mention.firstMatch(line);
    // `Log.scheme(config.url)` and `Log.redact(token)` are the sanctioned
    // renderings, and they are what a call site should say instead.
    if (hit != null && !RegExp(r'Log\.(scheme|redact)\s*\(').hasMatch(line)) {
      return hit.group(0);
    }
  }
  return null;
}

final _rules = <_LogRule>[
  _LogRule(
    name: 'log-through-the-logger',
    matches: (line) => _consoleCall.firstMatch(line)?.group(0)?.trim(),
    why:
        'Console writes go through Log, which is the only thing that knows to '
        'stay silent in release. A bare print survives into a shipped build.',
  ),
  _LogRule(
    name: 'one-logger',
    matches: (line) => _rivalLogger.firstMatch(line)?.group(0),
    why:
        'A second logger carries a second set of rules, and the weaker set is '
        'the one that leaks. Add a domain to Log instead of a class beside it.',
  ),
  _LogRule(
    name: 'no-secrets-in-a-line',
    matches: _secretInLogCall,
    why:
        'A proxy URL carries the credential that makes it work, and a token or '
        'key is the credential itself. Log Log.scheme(url) or Log.redact(token) '
        '— the protocol and the fact a secret was present are the useful part.',
  ),
];

void main() {
  final sources = [
    for (final root in [..._packageRoots, _enginePackageRoot])
      if (Directory(root).existsSync())
        ...dartSourcesUnder(root).where((f) => !_exempt(f.path)),
  ];

  test('every package is covered', () {
    // A root that stopped existing would make its rules silently vacuous.
    for (final root in _packageRoots) {
      expect(
        Directory(root).existsSync(),
        isTrue,
        reason:
            '$root is named as a package to check and is not there. Either the '
            'package moved, in which case fix the path, or it is gone, in '
            'which case drop it — a missing root checks nothing and says so to '
            'nobody.',
      );
    }
    expect(sources, isNotEmpty);
  });

  for (final rule in _rules) {
    test(rule.name, () {
      final offences = <String>[];

      for (final file in sources) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Whole-line comments are prose about the rule, not a breach of it.
          if (line.trimLeft().startsWith('//')) continue;
          final hit = rule.matches(line);
          if (hit != null) offences.add('${file.path}:${i + 1}  $hit');
        }
      }

      expect(
        offences,
        isEmpty,
        reason:
            '${rule.why}\n\n${offences.length} place(s):\n  ${offences.join('\n  ')}',
      );
    });
  }
}
