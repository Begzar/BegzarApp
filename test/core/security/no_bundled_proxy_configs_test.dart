import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_sources.dart';

/// A proxy scheme carrying a payload, e.g. `vless://<credentials>@host`.
///
/// The scheme constants the parsers match against are bare prefixes, so the
/// character after `://` is the closing quote — only a real config has more.
final _bundledConfig = RegExp(
  r'''(vless|vmess|trojan|ss|hysteria2?)://[^'"\s]''',
);

void main() {
  test('no proxy config is bundled into the Dart sources', () {
    final offenders = <String>[];

    for (final source in dartSourcesUnder('lib')) {
      final lines = source.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_bundledConfig.hasMatch(lines[i])) {
          offenders.add('${source.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Proxy configs carry credentials for servers we do not control and '
          'must come from the server at runtime. Remove them from: '
          '${offenders.join(', ')}',
    );
  });
}
