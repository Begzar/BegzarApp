/// How strongly a neutral is drawn over the page.
///
/// Glass and its text are the page's own neutral — `AppPalette.veil` — at an
/// alpha, so the alpha *is* the design, and it was being chosen separately in
/// four files.
///
/// They drifted the way near-identical numbers always do: secondary text at
/// 0.70 in two palettes and 0.75 in the third, tertiary at 0.50 and 0.55,
/// dividers at 0.08 and 0.09, borders at 0.14 and 0.20. Nobody could see it —
/// the screens are never open at the same time — and nobody could defend any
/// of the six values either.
///
/// This is the ladder they now share. A module still chooses which rung it
/// wants; it no longer invents the rung. Where a pair disagreed, the more
/// legible of the two won.
abstract final class SurfaceAlpha {
  // --- Ink -------------------------------------------------------------------

  /// Supporting text: a subtitle, a field label, a row's second line.
  static const textSecondary = 0.75;

  /// Text that is present but not being offered: a timestamp, a hint.
  static const textTertiary = 0.55;

  /// Text that has been turned down: a disabled row, a spent counter.
  static const textMuted = 0.40;

  // --- Surfaces --------------------------------------------------------------

  /// The faintest fill that still reads as a surface: a well inside a card.
  static const inset = 0.06;

  /// A card grouping several rows.
  static const card = 0.08;

  /// Glass carrying a whole reading, where the content has to stay legible
  /// against it.
  static const glass = 0.12;

  /// The strongest glass: a reading that has to hold against the gradient,
  /// like the pills carrying the IP and the ping.
  static const glassStrong = 0.15;

  /// The frosted square a lone glyph sits in, lit from the top-left corner.
  ///
  /// Stronger than anything above, and the two rungs are a pair: a shape this
  /// small has to carry its own edge, and at card or glass strength a 35pt box
  /// disappears into whatever is behind it. Both the home screen and the
  /// premium list stated these two numbers separately, for the same reason and
  /// with the same values.
  static const iconBoxHigh = 0.30;
  static const iconBoxLow = 0.10;

  // --- Edges -----------------------------------------------------------------

  /// The rim of something the eye should find: a card, a field, a pill.
  static const border = 0.20;

  /// The rim of something already found: a nested tile, a muted row.
  static const borderSoft = 0.12;

  /// A line between two rows of the same card.
  static const divider = 0.08;
}
