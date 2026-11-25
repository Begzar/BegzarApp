import 'dart:io';

/// A Dart source file, named the same way on every host.
///
/// `Directory.listSync` hands back paths in the host's own form, so on Windows
/// every separator is a backslash. The tests that read the sources match those
/// paths against forward-slash fragments — `lib/core/`, `/data/`, `/gen/` — and
/// a fragment that never matches does not fail by itself: it exempts nothing,
/// or governs nothing. On Windows the layer rules governed no file at all, and
/// passed.
class DartSource {
  DartSource._(this._file) : path = _file.path.replaceAll(r'\', '/');

  final File _file;

  /// Relative to where the suite runs, with `/` separators on every host.
  final String path;

  List<String> readAsLinesSync() => _file.readAsLinesSync();

  String readAsStringSync() => _file.readAsStringSync();
}

/// Every `.dart` file under [root], recursively.
List<DartSource> dartSourcesUnder(String root) => [
  for (final entity in Directory(root).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) DartSource._(entity),
];
