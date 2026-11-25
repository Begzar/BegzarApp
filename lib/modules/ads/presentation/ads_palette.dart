import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// The ads module's colours and motion, in one place.
///
/// A module palette rather than two private classes in the overlay widget,
/// for the same reason every other module has one: the values were reachable
/// only by the file that declared them, so the ad content below the gate row
/// reached for Material greys instead — three of them, opaque, over a surface
/// that is not grey.
///
/// Everything sits on [overlay], the app's ground, which is opaque on purpose
/// — an ad has to stop being the app for as long as it is up — and its
/// neutrals are the core palette's rungs, as they are on every other screen.
/// Read it once per build with [AdsPalette.of].
final class AdsPalette {
  const AdsPalette(this._core);

  factory AdsPalette.of(BuildContext context) => AdsPalette(context.palette);

  final AppPalette _core;

  // --- The gate row ---------------------------------------------------------

  /// Brightest at the leading edge, so the edge reads as the part that moves.
  static const railStops = <double>[0.0, 0.62, 1.0];

  /// One second, because the gate ticks once a second and the rail has exactly
  /// that long to cross the distance between two ticks.
  static const railSweep = Duration(seconds: 1);

  /// The rail cooling and the badge settling once the wait is over. Slower
  /// than [swap] so the row quietens behind the control rather than with it.
  static const settle = Duration(milliseconds: 550);

  /// The digits giving way to the close glyph.
  static const swap = Duration(milliseconds: 260);
  static const swapScale = 0.55;

  /// One beat on the knob as it becomes tappable. The wait ending is the only
  /// thing on this screen the reader is waiting for, so it is worth feeling
  /// rather than only seeing.
  static const unlockPulse = Duration(milliseconds: 520);
  static const unlockPeak = 1.12;

  /// The capsule is built from the same surface as the pills on the home
  /// screen, so the overlay's one piece of chrome reads as the app's rather
  /// than the advertiser's.
  Color get capsuleHigh => _core.surface;

  /// Amber stays what it already meant here: the ad, and its hold on the
  /// reader — the same thing this app says everywhere else it is waiting.
  Color get badge => _core.warning.withValues(alpha: _badgeFillAlpha);
  Color get badgeSpent => _core.warning.withValues(alpha: _badgeSpentAlpha);
  Color get badgeGlyph => _core.warningInk;
  Color get badgeLabel => _core.warningInk;

  static const _badgeFillAlpha = 0.18;
  static const _badgeSpentAlpha = 0.12;

  Color get railTrack => _core.surfaceRaised;

  List<Color> get railRunning => [
    for (final alpha in _railAlphas) _core.warning.withValues(alpha: alpha),
  ];
  static const _railAlphas = <double>[0.3, 0.58, 0.95];

  /// The finished rail, in the page's strong line rather than amber, because
  /// the wait is over and the line has stopped being the ad's hold on the
  /// reader. Three stops of one colour rather than a flat fill so it
  /// interpolates against [railRunning] stop for stop when the wait ends.
  List<Color> get railSpent => [for (final _ in railStops) _core.lineStrong];

  static const knobLocked = Colors.transparent;
  Color get knobUnlocked => _core.surfaceRaised;
  Color get knobDigits => _core.muted;
  Color get knobGlyph => _core.text;

  // --- The ad itself, on the opaque overlay ---------------------------------

  /// What the ad is shown on. Opaque: an ad has to stop being the app.
  Color get overlay => _core.overlay;

  /// The block standing in for a banner that has not arrived yet, and the
  /// glyph shown when one never will.
  Color get bannerStandIn => _core.surface;
  Color get bannerBroken => _core.faint;

  /// The hairline round the banner.
  Color get bannerRim => _core.line;

  /// The card the ad's words and its button sit on.
  Color get card => _core.surface;
  Color get cardRim => _core.lineStrong;
  Color get title => _core.text;

  /// The amber light at the top of the overlay: the wait is this screen's
  /// one piece of news.
  List<Color> get glow => [
    _core.warning.withValues(alpha: _glowAlpha),
    _core.warning.withValues(alpha: 0),
  ];
  static const _glowAlpha = 0.08;

  /// The skeleton shown while the ad is still on its way.
  Color get shimmerBase => _core.surface;
  Color get shimmerHighlight => _core.surfaceRaised;

  /// Body copy in the ad, which is the advertiser's text rather than the
  /// app's, so it sits a step below the title.
  Color get description => _core.muted;

  /// The spinner while the banner loads — amber, like everything else the ad
  /// makes the reader wait for.
  Color get spinner => _core.warningInk;

  // --- The skip warning -----------------------------------------------------

  /// Leaving an ad early is a warning, not a failure: the reader can still go
  /// back, and nothing has been lost.
  Color get warningFill => _core.warning.withValues(alpha: _warningFillAlpha);
  Color get warningGlyph => _core.warningInk;

  static const _warningFillAlpha = 0.2;
}
