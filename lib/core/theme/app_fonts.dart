import 'package:flutter/material.dart';

/// The three faces the design sets English in: [body] for running text,
/// [display] for the few lines that name a screen or a state, and [mono] for
/// readings — addresses, latencies, clocks, dates, counts.
///
/// English only. Persian keeps Estedad, and Chinese and Russian keep Poppins
/// and whatever the platform falls back to for their glyphs: the display and
/// mono faces bundled here carry Latin alone.
abstract final class AppFaces {
  static const body = 'Geist';
  static const display = 'Unbounded';
  static const mono = 'GeistMono';
}

/// Persian uses Estedad, English Geist, and the other languages Poppins.
String appFontFamilyFor(Locale locale) => switch (locale.languageCode) {
  'fa' => 'Estedad',
  'en' => AppFaces.body,
  _ => 'Poppins',
};

/// Whether [context] is set in the English faces.
bool _setsInAppFaces(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'en';

/// The display face for [context], or null where the language has none, so
/// the line keeps the body face it inherits.
String? displayFamilyOf(BuildContext context) =>
    _setsInAppFaces(context) ? AppFaces.display : null;

/// The mono face for [context], or null where the language has none, so
/// the reading keeps the body face it inherits.
String? monoFamilyOf(BuildContext context) =>
    _setsInAppFaces(context) ? AppFaces.mono : null;

/// Whether [family] is one of the Geist faces, whose em box is centred on
/// their capitals and figures.
bool _isGeist(String? family) =>
    family == AppFaces.body || family == AppFaces.mono;

/// How far a centred line of text has to come down to sit on the same line
/// as a glyph beside it, as a fraction of the font size.
///
/// A [Row] centres the em box a font declares, and a glyph's ink is centred
/// in its own box — Iconsax draws every one of them dead centre, which the
/// font file gives as 0.0000em. Text is not so obliging: a face reserves its
/// own room above and below the baseline, and the ink of a line sits wherever
/// that leaves it. Read off the two faces this app ships, the ink of the
/// home screen's latency reading centres 0.0185em above its box in Poppins
/// and 0.105em below it in Estedad — which, once each face's line height is
/// applied, lands the reading 2.5px high in English and 1.5px high in
/// Persian against the same glyph.
///
/// One number, because both faces err the same way. Splitting the difference
/// leaves half a pixel either side, where a per-face pair would buy that
/// half pixel at the price of a table this app cannot fill: Chinese and
/// Russian take their glyphs from whatever the platform falls back to, and
/// there is no machine here to measure them on.
///
/// Distinct from [opticalCentreAboveBaselineFor], which answers a different
/// question — where to put a baseline when a label is being placed in a box
/// of its own, rather than how far to move one that a row has already
/// centred.
const double kOpticalTextDrop = 0.05;

/// [kOpticalTextDrop] for a line set in [family].
///
/// Geist needs none: its box runs 1.005em above the baseline and 0.295em
/// below, which centres it at 0.355em — exactly half its 0.71em capitals and
/// figures, so a row that centres the box has already centred the ink.
double opticalTextDropFor(String? family) =>
    _isGeist(family) ? 0 : kOpticalTextDrop;

/// Where a short label set in [family] looks vertically centred, measured up
/// from its baseline as a fraction of the font size.
///
/// Anything centring text in a box of its own wants this instead of padding,
/// because padding centres a font's em box and an em box is not centred on
/// its letters. Estedad reserves room above for Persian diacritics that UI
/// labels never take, so its box centre sits at 0.293em while its capitals
/// reach 0.732em; Poppins puts its centre at 0.350em against a 0.705em cap.
/// Centre the box in both and the Persian label lands visibly low while the
/// Latin one looks about right — which is exactly what the plan badge did.
///
/// The two numbers are measured rather than computed from those metrics, and
/// they are further apart than the metrics alone would put them, because the
/// ink each script gives a short label is not the same band. Persian hangs
/// below the baseline — `پایه` descends 0.415em — where the plan names in
/// Latin have no descender at all and are topped instead by the dot on their
/// `i`, which stands above the cap height. Both were tuned on device until
/// the ink sat level in its pill to the pixel.
///
/// One number per face. Words do not agree with each other either: in Estedad
/// the weight of `پایه`'s ink centres 0.162em above the baseline and that of
/// `پریمیوم`, which has no tall letter in it at all, 0.083em. The face's
/// number is the one `پریمیوم` reads as centred on; a label whose weight sits
/// that far from it passes its own, as the plan badge does for `پایه`.
///
/// Geist's labels are set in capitals, and its box is centred on them, so
/// its value is simply half its cap height.
double opticalCentreAboveBaselineFor(String? family) => family == 'Estedad'
    ? 0.125
    : _isGeist(family)
    ? 0.355
    : 0.43;

/// Whether [family] sets a script whose letters join up.
///
/// Tracking is the thing this gates. Letter-spacing is a Latin typographic
/// device, and Flutter applies it after shaping, so on Persian it pulls the
/// shaped letters apart while leaving them in their connected forms — `بگذر`
/// comes out as four pieces of a word rather than a word. Anything spacing a
/// display line has to ask this first.
bool joinsLetters(String? family) => family == 'Estedad';

/// The face the ad popup is set in, and its card whenever the ad's copy reads
/// right to left. Copy in any other script takes the app's own face.
const String kAdPopupFontFamily = 'Estedad';
