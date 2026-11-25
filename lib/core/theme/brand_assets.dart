import 'dart:ui' show Offset;

/// Image assets that carry the brand itself, rather than one screen's
/// decoration.
///
/// They live here because more than one module paints them, and because a
/// brand mark that two screens spell out by hand is a brand mark those two
/// screens will eventually disagree about — which is exactly what happened to
/// the bird before this file existed.
abstract final class BrandAssets {
  /// The bird, drawn for the dark backgrounds every screen paints: white with
  /// the blue wing streaks.
  ///
  /// It is the launcher icon's own dark-appearance artwork, written by
  /// `tool/app_icon/generate_icons.py` from the same source as the icon, so
  /// the mark on screen and the icon on the home screen cannot drift apart.
  /// Regenerate it there rather than editing the file if the icon changes.
  static const bird = 'assets/images/bird_mark.png';

  /// Only the bird's two wing streaks, on a canvas the same size as [bird]
  /// and cut from the same box, so drawn over it they land on its own.
  ///
  /// Written by the same run of the generator as [bird]; regenerate the two
  /// together.
  static const birdAccent = 'assets/images/bird_accent.png';

  /// The shift, as a fraction of the bird's own size, that puts its visual
  /// weight rather than its box at the centre of whatever it is centred on.
  ///
  /// The wings and tail pull the weight left of and above the middle of the
  /// canvas. Measured as the artwork's alpha-weighted centre against the
  /// centre of its canvas, so re-measure it whenever [bird] is re-exported.
  static const birdOpticalCentring = Offset(0.096, 0.025);
}
