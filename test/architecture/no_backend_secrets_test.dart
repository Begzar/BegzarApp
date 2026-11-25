import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The backend is the private engine's: where its calls go, how they are
/// secured and signed, their routes and how their answers are read. The app
/// asks the engine for operations and never sees any of it, and none of it may
/// come back anywhere in this repository — code, tests, tools, docs or the
/// native projects — because all of it is published.
///
/// What counts is listed in the private engine, since the list itself names
/// the backend. Without the engine checked out there is nothing to check
/// against, and nothing here could have learned it.
const _terms = 'begzar-engine/docs/backend/forbidden_in_app.txt';

/// Not this repository's to publish: the private engine, what tools generate,
/// and version control.
const _skippedDirectories = {
  '.git',
  'begzar-engine',
  'build',
  '.dart_tool',
  'dist',
  'Pods',
  '.symlinks',
  '.idea',
  '.gradle',
  '.cxx',
  'ephemeral',
  'node_modules',
  // The private engine, built here for Apple and never committed.
  'BegzarEngineKit.xcframework',
  'libbegzar_engine.xcframework',
};

Iterable<File> _publishedFiles(Directory root) sync* {
  for (final entity in root.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (entity is Directory) {
      if (_skippedDirectories.contains(name)) continue;
      yield* _publishedFiles(entity);
    } else if (entity is File) {
      yield entity;
    }
  }
}

/// The file's text, or null for a binary one.
String? _textOf(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.contains(0)) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// The engine's list, as what each term is and the term, or null when the
/// engine is not checked out.
List<(String, String)>? _forbidden() {
  final file = File(_terms);
  if (!file.existsSync()) return null;
  return [
    for (final line in file.readAsLinesSync())
      if (line.isNotEmpty && !line.startsWith('#'))
        (line.split('\t').first, line.split('\t').last),
  ];
}

void main() {
  final forbidden = _forbidden();

  test('nothing in the repository describes the backend', () {
    final root = Directory.current;
    final offenders = <String>[];

    for (final file in _publishedFiles(root)) {
      final path = file.path.substring(root.path.length + 1);
      final text = _textOf(file);
      if (text == null) continue;
      for (final (what, needle) in forbidden!) {
        if (text.contains(needle)) offenders.add('$path ($what)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The engine owns the backend; this repository is published. '
          'Remove from: ${offenders.join(', ')}',
    );
  }, skip: forbidden == null ? 'the private engine is not checked out' : false);
}
