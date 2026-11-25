import 'package:flutter_test/flutter_test.dart';

import '../support/dart_sources.dart';

/// Enforces the layering every module is on: Presentation over Application
/// over Domain over Data. A layer may reference the layer below it and nothing
/// above; Domain references nothing.
///
/// Around the modules sit two things that are not layers. `lib/core/` is the
/// floor they all stand on and may not know any of them. `lib/app/` is the
/// shell above them all: it composes modules into a running app, so it may
/// depend on every one of them and nothing may depend on it.
///
/// These rules are the mechanical half of that contract — they read the import
/// lines and fail the suite when one crosses a boundary. `architecture.md` is
/// the prose half: it explains what each layer is for and why the rules are
/// drawn where they are. Keep the two in step — a rule changed here without a
/// line changed there leaves the reasoning describing a guard that is gone.
///
/// This landed with a baseline of 21 crossings that predated it, on the
/// promise that the list would only ever shrink. It reached zero, and the
/// escape hatch went with it: there is nowhere left to record an exception,
/// so a crossing is now simply a failure.
class _LayerRule {
  const _LayerRule({
    required this.name,
    required this.appliesTo,
    required this.forbids,
    required this.why,
  });

  final String name;

  /// True when this rule governs the file at [path].
  final bool Function(String path) appliesTo;

  /// True when [import] is a crossing this rule disallows.
  final bool Function(String import) forbids;

  /// Shown when the rule fires, so the failure explains itself.
  final String why;
}

bool _under(String path, String segment) => path.contains('/$segment/');

/// The Data layer.
bool _isData(String path) => _under(path, 'data');

/// Wiring files: the only place allowed to know the Riverpod container exists.
/// Declaring providers is their entire job, so the container rule skips them.
bool _isCompositionRoot(String path) =>
    _under(path, 'di') ||
    path.endsWith('_provider.dart') ||
    path.endsWith('_providers.dart');

/// Packages that make a file impure — anything Flutter, Riverpod, an HTTP
/// client, or direct platform access.
const _impureDeps = <String>[
  'package:flutter/',
  'package:flutter_riverpod/',
  'package:hooks_riverpod/',
  'package:flutter_hooks/',
  'package:dio/',
  'dart:io',
  'dart:ui',
];

const _riverpodDeps = <String>[
  'package:flutter_riverpod/',
  'package:hooks_riverpod/',
];

final _rules = <_LayerRule>[
  _LayerRule(
    name: 'domain-is-pure',
    appliesTo: (p) => _under(p, 'domain'),
    forbids: (i) => _impureDeps.any(i.startsWith),
    why:
        'Domain is plain Dart. It models the problem, so it cannot depend on '
        'Flutter, Riverpod, an HTTP client, or the platform.',
  ),
  _LayerRule(
    name: 'domain-imports-only-domain',
    appliesTo: (p) => _under(p, 'domain'),
    forbids: (i) => i.startsWith('package:begzar/') && !i.contains('/domain/'),
    why:
        'A domain file may only reach other domain files. Reaching sideways '
        'into core/ or another layer is how import cycles start.',
  ),
  _LayerRule(
    name: 'data-below-presentation',
    appliesTo: _isData,
    forbids: (i) => i.contains('/presentation/'),
    why: 'Data sits below Presentation and must never import it.',
  ),
  _LayerRule(
    name: 'data-has-no-container',
    appliesTo: (p) => _isData(p) && !_isCompositionRoot(p),
    forbids: (i) => _riverpodDeps.any(i.startsWith),
    why:
        'A repository or data source takes its inputs as constructor '
        'parameters. Reading a provider couples it to whichever module '
        'declared that provider, and makes it untestable without one.',
  ),
  _LayerRule(
    name: 'application-below-presentation',
    appliesTo: (p) => _under(p, 'application'),
    forbids: (i) => i.contains('/presentation/'),
    why: 'Application sits below Presentation and must never import it.',
  ),
  _LayerRule(
    name: 'core-has-no-feature-deps',
    appliesTo: (p) => p.startsWith('lib/core/'),
    forbids: (i) => i.contains('package:begzar/modules/'),
    why:
        'core/ is the shared floor every module stands on. Importing a '
        'feature module from it inverts the dependency and makes core a '
        'sibling rather than a floor.',
  ),
  _LayerRule(
    name: 'app-shell-is-a-leaf',
    appliesTo: (p) =>
        p.startsWith('lib/core/') || p.startsWith('lib/modules/'),
    forbids: (i) => i.startsWith('package:begzar/app/'),
    why:
        'lib/app/ is the shell: it composes modules into a running app, so '
        'it is the one place allowed to depend on all of them. That only '
        'holds while nothing depends on it back — a module reaching into the '
        'shell would put the composition root underneath the things it '
        'composes.',
  ),
];

/// Matches an import directive and captures the target URI. Imports sit at the
/// top of a Dart file, before any declaration, so a line scan is enough.
final _importDirective = RegExp('''^\\s*import\\s+['"]([^'"]+)['"]''');

/// Every crossing in `lib/`, as `<file>|<import>` mapped to the rule that
/// caught it.
Map<String, _LayerRule> _findCrossings(List<DartSource> sources) {
  final found = <String, _LayerRule>{};

  for (final source in sources) {
    for (final line in source.readAsLinesSync()) {
      final match = _importDirective.firstMatch(line);
      if (match == null) continue;
      final import = match.group(1)!;

      for (final rule in _rules) {
        if (!rule.appliesTo(source.path)) continue;
        if (!rule.forbids(import)) continue;
        found['${source.path}|$import'] = rule;
      }
    }
  }

  return found;
}

String _explain(MapEntry<String, _LayerRule> crossing) {
  final parts = crossing.key.split('|');
  return '  [${crossing.value.name}] ${parts.first}\n'
      '      imports ${parts.last}\n'
      '      ${crossing.value.why}';
}

void main() {
  final sources = [
    for (final source in dartSourcesUnder('lib'))
      // Generated localizations are not hand-written and are not layered.
      if (!source.path.contains('/l10n/gen/')) source,
  ];

  test('every rule governs at least one file', () {
    // A rule that matches no path passes without looking at anything. Each of
    // these did, on Windows, until the paths were normalized.
    for (final rule in _rules) {
      expect(
        sources.any((source) => rule.appliesTo(source.path)),
        isTrue,
        reason:
            '${rule.name} governs no file under lib/, so it checks nothing and '
            'passes. Either the paths it matches on moved, in which case fix '
            'the rule, or its layer is gone, in which case drop it.',
      );
    }
  });

  test('no import crosses a layer boundary', () {
    final offenders = _findCrossings(sources).entries.map(_explain).toList()
      ..sort();

    expect(
      offenders,
      isEmpty,
      reason:
          'The imports listed above cross a layer boundary. Depend downward, '
          'or move the shared piece to a layer both sides may reach. There is '
          'no baseline to add them to — the migration emptied it.',
    );
  });
}
