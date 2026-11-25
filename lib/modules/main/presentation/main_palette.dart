import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/main/domain/ping_quality.dart';
import 'package:flutter/material.dart';

/// The home screen's colours, shapes and motion, in one place.
///
/// These are per-module tokens, not an app-wide dump. Every colour names a
/// role of the [AppPalette] it is built from — the connected blue among them —
/// rather than restating it, so this screen and the premium screens cannot
/// drift apart, and the screen follows the theme it is drawn in.
///
/// Read it once per build with [MainPalette.of]. Shapes and motion do not
/// change with the theme, so they stay static.
final class MainPalette {
  const MainPalette(this._core);

  factory MainPalette.of(BuildContext context) => MainPalette(context.palette);

  final AppPalette _core;

  // --- Connection states ---------------------------------------------------

  /// A tunnel that is up.
  Color get connected => _core.connectedInk;

  /// In flight: connecting or disconnecting.
  Color get inFlight => _core.warning;

  /// A connect that failed. The one place the destructive colour belongs on
  /// this screen.
  Color get failed => _core.failed;

  /// A failed connect drawn as ink rather than as a fill: the dial's light
  /// and its rim, both of them over glass, where the deep [failed] goes muddy.
  Color get failedInk => _core.failedInk;

  /// A tunnel that is up but carries no traffic: a warning, not a failure, so
  /// the warning ink rather than [failed].
  Color get stalled => _core.warningInk;

  /// Ready, and the resting colour of everything else.
  Color get idle => _core.text;

  /// The light the dial rests in: a cool slate, so the dial reads as
  /// waiting rather than lit. Amber, blue and red are kept for news. The
  /// same slate in either theme, because the bird it lights is white.
  static const dialAtRest = Color(0xFF7892B6);

  /// The two stops the dial's disc is drawn in, lit with [tint].
  ///
  /// Over a dark page the disc is glass filmed in its light. Over a light page
  /// glass that thin washes out to nothing, and the white bird with it, so
  /// the disc is solid there: the light, lifted at the top corner and shaded
  /// at the far one.
  List<Color> dialStops(Color tint) => switch (_core.brightness) {
    Brightness.dark => [
      tint.withValues(alpha: _dialFilmHigh),
      tint.withValues(alpha: _dialFilmLow),
    ],
    Brightness.light => [
      Color.lerp(tint, AppPalette.lift, _dialLift)!,
      Color.lerp(tint, AppPalette.shade, _dialShade)!,
    ],
  };
  static const _dialFilmHigh = 0.24;
  static const _dialFilmLow = 0.08;
  static const _dialLift = 0.25;
  static const _dialShade = 0.15;

  /// The way in: the ring round a dial at rest and the hint under it. The
  /// app's accent is its primary action, and at rest the dial is that action;
  /// the glass itself stays slate, so a dial asking to be pressed never reads
  /// as a tunnel that is up.
  Color get invite => _core.accent;

  /// The glyph leading the line under the server, which opens the settings
  /// it reads out. The line has no chevron, so the accent, the colour of
  /// what a press does on this screen, is what says it can be pressed.
  Color get settingsLineGlyph => _core.accent;

  // --- Surfaces ----------------------------------------------------------

  /// A hairline between two readings on one card.
  Color get divider => _core.line;

  /// The exit address, its placeholder bars and the lines that dim from it:
  /// the page's own neutral, at full strength or an alpha of it.
  Color get readingInk => _core.veil;

  /// The check beside a reading the app has verified.
  Color get verified => _core.premiumInk;

  /// The tile a flag sits in on a card.
  Color get flagBox => _core.surfaceRaised;

  /// The bars a reading is drawn as while it loads.
  Color get shimmerBase => _core.veil.withValues(alpha: _shimmerBaseAlpha);
  Color get shimmerHighlight =>
      _core.veil.withValues(alpha: _shimmerHighlightAlpha);
  static const _shimmerBaseAlpha = 0.2;
  static const _shimmerHighlightAlpha = 0.4;

  // --- Text --------------------------------------------------------------

  Color get textPrimary => _core.text;
  Color get textSecondary => _core.textSecondary;
  Color get textTertiary => _core.muted;
  Color get textFaint => _core.faint;

  /// One breath of the ring that invites the tap round a dial at rest.
  static const dialInvite = Duration(milliseconds: 3600);

  /// The stillness between two breaths, when a home screen at rest draws
  /// nothing at all.
  static const dialInviteRest = Duration(milliseconds: 2400);

  /// The invite rings coming in round a dial that starts inviting, as the
  /// home dial does when it takes over from the launch dial.
  static const dialInviteReveal = Duration(milliseconds: 480);

  // --- Shape -------------------------------------------------------------

  /// The appbar's button. One value rather than a literal at the call site,
  /// because the tap target below is derived from it.
  ///
  /// Deliberately small: the app's name opposite is the thing the top of the
  /// screen is about, and a control that matched it in weight fought it.
  static const appBarButtonSize = 40.0;

  /// The glyph inside it, sized to leave the box a rim rather than filling it
  /// edge to edge.
  static const appBarGlyphSize = 16.0;

  /// What a finger gets, as opposed to what the eye gets. The button carries a
  /// transparent ring out to this size, so it looks small and still cannot be
  /// missed.
  ///
  /// Short of the 48 Material asks for. That was settled when two controls sat
  /// side by side up here and the target was also the pitch between them — at
  /// 48 their boxes had to overlap, and a tap landing in an overlap goes to
  /// whichever is drawn on top rather than to the button under the finger.
  /// Only one control is left, so the constraint is gone; the value stays
  /// because 44 is what the bar was measured and tuned at, and growing it now
  /// would move the button without anything asking for it.
  static const appBarTapTarget = 44.0;

  // --- Motion ------------------------------------------------------------

  /// The background gradient following a connection-status change.
  static const backgroundShift = Duration(milliseconds: 200);

  /// A control changing state in place: the badge, the toggle's fill.
  static const stateChange = Duration(milliseconds: 220);

  /// One body replacing another under the appbar.
  static const bodySwap = Duration(milliseconds: 360);

  // --- App bar ---------------------------------------------------------------

  /// The app's name, and the glyph in the channel button.
  Color get appBarInk => _core.text;

  /// The channel button: an opaque tile with a hairline rim.
  Color get appBarButtonFill => _core.surface;
  Color get appBarButtonRim => _core.line;

  // --- Nav bar ---------------------------------------------------------------

  /// The bar itself: a solid raised surface with a hairline rim. Solid
  /// because nothing frosts what passes under it, and rows seen sharp through
  /// a see-through fill would sit among its icons.
  Color get navFill => _core.surfaceRaised;
  Color get navRim => _core.lineStrong;

  /// The selected tab: a tint of the accent with a rim of it, carrying the
  /// glyph in the accent itself. A light pill was the brightest thing on the
  /// home screen and drew the eye off the dial.
  Color get navSelected => _core.accent.withValues(alpha: _navSelectedAlpha);
  Color get navSelectedRim =>
      _core.accent.withValues(alpha: _navSelectedRimAlpha);
  Color get navOnSelected => _core.accent;
  static const _navSelectedAlpha = 0.14;
  static const _navSelectedRimAlpha = 0.32;

  /// A tab at rest. The muted rung rather than the faint one, which falls
  /// short of the 3:1 a glyph needs on the bar.
  Color get navResting => _core.muted;
}

/// What each latency band looks like on the ping pill.
///
/// Kept out of [PingQuality] itself: the domain grades a measurement, it does
/// not know what colour a screen paints it.
///
/// Three tones for four bands, and they are the three the premium picker
/// paints its own readings with. This used to be the raw Material palette —
/// green, yellow, orange, red — which meant the same round trip was drawn in
/// one vocabulary on the home screen and another one tap away. Excellent and
/// good share the healthy tone because the label beside the pill already
/// tells the two apart, and because the picker has always treated a signal as
/// strong or not.
extension PingQualityColor on PingQuality {
  Color colorIn(MainPalette palette) => switch (this) {
    PingQuality.excellent || PingQuality.good => palette._core.premiumInk,
    PingQuality.fair => palette._core.warningInk,
    PingQuality.poor => palette._core.failedInk,
  };
}
