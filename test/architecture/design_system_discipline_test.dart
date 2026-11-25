import 'package:flutter_test/flutter_test.dart';

import '../support/dart_sources.dart';

/// Enforces that a screen is drawn out of the design system rather than out of
/// whatever was to hand.
///
/// Every rule here was a real divergence before it was a rule. The home plan
/// badge and the account screen painted the same subscription two different
/// greens; settings drew itself in Material icons while the shell around it
/// used Iconsax; the notification gate hand-copied the page gradient and lost
/// its stop weighting on the way, so the first screen a new install saw was
/// visibly lighter than every screen after it. None of that was caught by
/// review, because each one looks reasonable in the diff that introduces it —
/// it is only wrong next to a screen nobody opened at the same time.
///
/// The same bargain `logging_discipline_test.dart` and
/// `layer_boundaries_test.dart` make: a rule only a person can enforce is a
/// rule that holds until the first hurry.
class _DesignRule {
  const _DesignRule({
    required this.name,
    required this.matches,
    required this.why,
    required this.exempt,
  });

  final String name;

  /// The offending fragment in a line of source, or null when it is clean.
  final String? Function(String line) matches;

  /// Printed when the rule fires, so the failure explains itself rather than
  /// pointing at a line number and leaving the reader to guess.
  final String why;

  /// Files this rule does not apply to, by path suffix or fragment.
  final bool Function(String path) exempt;
}

/// Generated bindings, which nobody writes by hand.
bool _generated(String path) => path.contains('/gen/');

/// The token layer itself: the files whose whole job is to state a value once.
///
/// A palette is where a literal is allowed to be written down. Everywhere else
/// names it.
bool _tokenLayer(String path) => path.endsWith('_palette.dart');

/// A colour taken straight from the Material palette.
///
/// `white`, `black` and `transparent` are primitives rather than a palette, so
/// they are not what this rule is about — [_fixedNeutral] is. A hue is:
/// `Colors.green` is a decision about what green means, made at a call site,
/// where it cannot be seen next to the other one.
final _materialHue = RegExp(
  r'\bColors\.(?!white\b|black\b|transparent\b)[a-z]\w*',
);

/// White or black written at a call site.
///
/// Every neutral in this app is the page's own neutral at an alpha, and which
/// neutral that is depends on the theme: white over a dark page, the ink over
/// a light one. A `Colors.white` written into a widget is white in both, and
/// vanishes on the light page.
final _fixedNeutral = RegExp(r'\bColors\.(white|black)\b');

/// A colour written as a literal.
final _colourLiteral = RegExp(
  r'\bColor\(0x[0-9a-fA-F]{6,8}\)|\bColor\.fromARGB\(',
);

/// A Material icon. The app's icon family is Iconsax; the two sets have
/// different stroke weights and read as different products at the same size.
final _materialIcon = RegExp(r'\bIcons\.\w+');

/// A font size written as a number rather than taken from the ramp.
final _rawFontSize = RegExp(r'fontSize:\s*\d');

/// A scrim written as a number. How dark the world goes behind a popup is a
/// property of the app, not of which popup it is.
final _rawBarrier = RegExp(r'barrierColor:.*\d\.\d');

final _rules = <_DesignRule>[
  _DesignRule(
    name: 'no-material-hues',
    matches: (line) => _materialHue.firstMatch(line)?.group(0),
    exempt: (path) => _generated(path) || _tokenLayer(path),
    why:
        'A hue picked at a call site cannot be seen next to the other place '
        'that means the same thing, which is how the app came to have six '
        'greens and eight reds. Name it in the module palette, or in '
        'AppPalette when more than one module means it.',
  ),
  _DesignRule(
    name: 'no-fixed-neutrals',
    matches: (line) => _fixedNeutral.firstMatch(line)?.group(0),
    exempt: (path) => _generated(path) || _tokenLayer(path),
    why:
        'White and black are only the neutral of one theme. Read the page '
        'neutral from the palette (AppPalette.veil, its text roles), or, for '
        'something lit the same on either page, AppPalette.lift, shade or '
        'scrim.',
  ),
  _DesignRule(
    name: 'no-colour-literals',
    matches: (line) => _colourLiteral.firstMatch(line)?.group(0),
    exempt: (path) => _generated(path) || _tokenLayer(path),
    why:
        'A hex literal outside the token layer is a colour nobody can find '
        'again. Put it in the palette that owns it.',
  ),
  _DesignRule(
    name: 'one-icon-family',
    matches: (line) => _materialIcon.firstMatch(line)?.group(0),
    exempt: _generated,
    why:
        'This app draws in Iconsax. Material icons are heavier at the same '
        'point size, so a screen that mixes them reads as a different product '
        'than the tab beside it.',
  ),
  _DesignRule(
    name: 'type-comes-from-the-ramp',
    matches: (line) => _rawFontSize.firstMatch(line)?.group(0),
    exempt: _generated,
    why:
        'AppLayout publishes the type ramp. A size written at the call site is '
        'how 24sp — which is not a step on it — reached a shipped screen.',
  ),
  _DesignRule(
    name: 'one-scrim',
    matches: (line) => _rawBarrier.firstMatch(line)?.group(0),
    exempt: _generated,
    why:
        'Five dialogs had five scrims. Use AppLayout.scrimAlpha so a popup is '
        'as dark as a popup, whichever one it is.',
  ),
];

void main() {
  final sources = dartSourcesUnder('lib');

  test('there is something to check', () {
    expect(sources, isNotEmpty);
  });

  for (final rule in _rules) {
    test(rule.name, () {
      final offences = <String>[];

      for (final file in sources) {
        if (rule.exempt(file.path)) continue;
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          // Whole-line comments are prose about the rule, not a breach of it.
          if (line.trimLeft().startsWith('//')) continue;
          if (line.trimLeft().startsWith('///')) continue;
          final hit = rule.matches(line);
          if (hit != null) offences.add('${file.path}:${index + 1}  $hit');
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
