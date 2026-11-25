import 'package:begzar/core/domain/surface_mood.dart';
import 'package:flutter/material.dart';

/// The app's colours, as one value the theme carries.
///
/// Every screen reads its colours from the [AppPalette] of the theme it is
/// drawn in, through [AppPaletteOf.palette], rather than from constants. That
/// is what lets one tree be drawn dark or light: the theme swaps the palette,
/// and every widget that read a colour from it rebuilds.
///
/// A module palette never states a colour that means the same thing here; it
/// names the role it wants and adds only what is its own.
@immutable
final class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceLive,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textSecondary,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.premium,
    required this.premiumInk,
    required this.connected,
    required this.connectedInk,
    required this.failed,
    required this.failedInk,
    required this.warning,
    required this.warningInk,
    required this.dialog,
    required this.sheet,
    required this.overlay,
    required this.snack,
    required this.onSnack,
    required this.snackFailure,
    required this.errorToast,
    required this.noticeToast,
    required this.planPremiumRim,
    required this.planBasicRim,
    required this.planBasicInk,
    required this.veil,
    required this.shadow,
    required this.schemePrimary,
    required this.schemeSecondary,
    required this.pageIdle,
    required this.pageBusy,
    required this.pageActive,
    required this.pageAlert,
  });

  /// Which way the palette runs, for the few colours a module owns outright
  /// and has to choose for itself.
  final Brightness brightness;

  // --- Ink -------------------------------------------------------------------

  /// The ground every screen is drawn on.
  final Color page;

  /// A card, a field, a pill on [page].
  final Color surface;

  /// A small shape raised on [surface]: a glyph's tile, a selected segment.
  final Color surfaceRaised;

  /// A raised surface that holds the live connection.
  final Color surfaceLive;

  /// The rim of a surface, and a stronger rim for what is raised.
  final Color line;
  final Color lineStrong;

  /// Text, from the title down to what is present but not offered.
  final Color text;
  final Color textSecondary;
  final Color muted;

  /// Glyphs and chevrons. Too light for text a reader has to read.
  final Color faint;

  /// The primary action, the selected thing, a tunnel up.
  final Color accent;
  final Color accentDeep;

  /// A label on an [accent] fill.
  final Color onAccent;

  // --- Meaning ---------------------------------------------------------------

  /// Premium as a fill: the plan badge, the servers toggle.
  final Color premium;

  /// Premium as ink: entitled status text, a healthy ping, a rule that lets
  /// traffic past.
  final Color premiumInk;

  /// A tunnel that is up, as a fill.
  final Color connected;

  /// The tunnel as ink, where a fill would go muddy.
  final Color connectedInk;

  /// A connect that failed, deep enough to floor a shape.
  final Color failed;

  /// Failure as ink, and the destructive tone generally.
  final Color failedInk;

  /// In flight, and warning, as a fill.
  final Color warning;

  /// The same as ink. One value with [warning] on a dark ground, where amber
  /// reads as text; a darker one on a light ground, where it does not.
  final Color warningInk;

  // --- Opaque surfaces --------------------------------------------------------

  /// A dialog over the page.
  final Color dialog;

  /// A sheet raised from the bottom edge, over a list.
  final Color sheet;

  /// A full-screen overlay that hides the app behind it.
  final Color overlay;

  /// A snackbar, and the ink on it.
  final Color snack;
  final Color onSnack;
  final Color snackFailure;

  /// The toast carrying a connection error, warmed towards failure.
  final Color errorToast;

  /// The toast carrying a notice, warmed towards [warning].
  final Color noticeToast;

  // --- Plan badge -------------------------------------------------------------

  /// Premium as an outlined tag; its label is [accent].
  final Color planPremiumRim;

  /// Basic as an outlined tag: a hairline rim and a muted label.
  final Color planBasicRim;
  final Color planBasicInk;

  // --- Glass ------------------------------------------------------------------

  /// The neutral drawn straight onto the page: glass filmed in it at the
  /// alphas `SurfaceAlpha` names, and the few readings set in it outright.
  /// White on a dark page; the ink on a light one.
  final Color veil;

  /// What a raised shape casts.
  final Color shadow;

  // --- Material ---------------------------------------------------------------

  /// What Material paints its own controls in where a widget names no colour.
  final Color schemePrimary;
  final Color schemeSecondary;

  // --- Page light -------------------------------------------------------------

  /// The page backgrounds by mood. Three stops, weighted so the middle colour
  /// holds most of the screen and the last one only darkens the bottom edge.
  final List<Color> pageIdle;
  final List<Color> pageBusy;
  final List<Color> pageActive;
  final List<Color> pageAlert;

  static const _pageStops = <double>[0.0, 0.38, 1.0];

  /// The light a lit fill is lifted towards at its top corner, and the dark a
  /// lit shape is shaded towards at its far edge, in either theme: a shape is
  /// lit the same way whatever page it sits on.
  static const lift = Color(0xFFFFFFFF);
  static const shade = Color(0xFF000000);

  /// What a dialog or a sheet dims the screen behind it with. Black in either
  /// theme, at the alpha the caller names, as Material's own scrim is.
  static const scrim = Color(0xFF000000);

  /// The label on a light fill, and on a deep one.
  ///
  /// A label follows its fill, not the theme: amber takes the dark label on a
  /// light page as much as on a dark one.
  static const labelOnBright = Color(0xFF04121F);
  static const labelOnDeep = Color(0xFFEDF0F4);

  /// Whichever of [labelOnBright] and [labelOnDeep] reads on [fill].
  static Color labelOn(Color fill) =>
      ThemeData.estimateBrightnessForColor(fill) == Brightness.light
      ? labelOnBright
      : labelOnDeep;

  static const dark = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF0A0D12),
    surface: Color(0xFF11161D),
    surfaceRaised: Color(0xFF171E27),
    surfaceLive: Color(0xFF16233A),
    line: Color(0x14D6E2F0),
    lineStrong: Color(0x24D6E2F0),
    text: Color(0xFFEDF0F4),
    textSecondary: Color(0xFFB3BAC5),
    muted: Color(0xFF8B95A4),
    faint: Color(0xFF5B6573),
    accent: Color(0xFF4DA8FF),
    accentDeep: Color(0xFF2B7FF0),
    onAccent: Color(0xFF04121F),
    premium: Color(0xFF228C46),
    premiumInk: Color(0xFF5ED6B8),
    connected: Color(0xFF2B7FF0),
    connectedInk: Color(0xFF4DA8FF),
    failed: Color(0xFFBA1C1C),
    failedInk: Color(0xFFF0797A),
    warning: Color(0xFFF5B83D),
    warningInk: Color(0xFFF5B83D),
    dialog: Color(0xFF171E27),
    sheet: Color(0xFF11161D),
    overlay: Color(0xFF0A0D12),
    snack: Color(0xFF171E27),
    onSnack: Color(0xFFEDF0F4),
    snackFailure: Color(0xFF2A1719),
    errorToast: Color(0xFF241417),
    noticeToast: Color(0xFF231E12),
    planPremiumRim: Color(0x734DA8FF),
    planBasicRim: Color(0x24D6E2F0),
    planBasicInk: Color(0xFF8B95A4),
    veil: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    schemePrimary: Color(0xFF1B1A20),
    schemeSecondary: Color(0xFF2F2E35),
    pageIdle: [Color(0xFF0D131C), Color(0xFF0A0D12), Color(0xFF080A0E)],
    pageBusy: [Color(0xFF19150C), Color(0xFF0B0D11), Color(0xFF090A0D)],
    pageActive: [Color(0xFF0B1A2E), Color(0xFF0A0D12), Color(0xFF080A0E)],
    pageAlert: [Color(0xFF1B0F12), Color(0xFF0B0C10), Color(0xFF090A0D)],
  );

  /// The light theme, role for role against [dark].
  ///
  /// Text inks are darker here, not lighter, so every text role still reads at
  /// 4.5:1 on a card and on the page. Amber cannot be ink on a light page, so
  /// [warningInk] parts from [warning] here; the fills — [premium], [failed],
  /// [warning] — keep their values. Snacks are the inverse surface, as
  /// Material's are on a light page.
  ///
  /// The page is a cool grey rather than near-white, and a card on it is
  /// off-white, so a card's edge shows by its tone as well as its hairline.
  /// Pure white is kept for what floats — [dialog] and [sheet] — which makes
  /// three steps where a white card on a white page made two that read as
  /// one. The page is as dark as [muted] allows on it; darker needs darker
  /// inks.
  static const light = AppPalette(
    brightness: Brightness.light,
    page: Color(0xFFE2E7EE),
    surface: Color(0xFFF4F6F9),
    surfaceRaised: Color(0xFFE3E8EF),
    surfaceLive: Color(0xFFE4EEFB),
    line: Color(0x240E1420),
    lineStrong: Color(0x380E1420),
    text: Color(0xFF0E1420),
    textSecondary: Color(0xFF3A4454),
    muted: Color(0xFF5B6575),
    faint: Color(0xFF8A94A3),
    accent: Color(0xFF1563C7),
    accentDeep: Color(0xFF0F4FA3),
    onAccent: Color(0xFFFFFFFF),
    premium: Color(0xFF228C46),
    premiumInk: Color(0xFF0C7058),
    connected: Color(0xFF0F4FA3),
    connectedInk: Color(0xFF1563C7),
    failed: Color(0xFFBA1C1C),
    failedInk: Color(0xFFC2272D),
    warning: Color(0xFFF5B83D),
    warningInk: Color(0xFF905400),
    dialog: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    overlay: Color(0xFFE2E7EE),
    snack: Color(0xFF1B2230),
    onSnack: Color(0xFFEDF0F4),
    snackFailure: Color(0xFF3A1D20),
    errorToast: Color(0xFFFDECEC),
    noticeToast: Color(0xFFFDF3DF),
    planPremiumRim: Color(0x731563C7),
    planBasicRim: Color(0x380E1420),
    planBasicInk: Color(0xFF5B6575),
    veil: Color(0xFF0E1420),
    shadow: Color(0xFF0E1420),
    schemePrimary: Color(0xFF1563C7),
    schemeSecondary: Color(0xFFE3E8EF),
    pageIdle: [Color(0xFFD5DFEC), Color(0xFFE2E7EE), Color(0xFFE5E9EF)],
    pageBusy: [Color(0xFFECE2CD), Color(0xFFE4E8EE), Color(0xFFE5E9EF)],
    pageActive: [Color(0xFFC6D8EE), Color(0xFFE2E7EE), Color(0xFFE5E9EF)],
    pageAlert: [Color(0xFFECD5DA), Color(0xFFE4E8EE), Color(0xFFE5E9EF)],
  );

  List<Color> _pageColors(SurfaceMood mood) => switch (mood) {
    SurfaceMood.idle => pageIdle,
    SurfaceMood.busy => pageBusy,
    SurfaceMood.active => pageActive,
    SurfaceMood.alert => pageAlert,
  };

  /// Top-to-bottom page background for [mood].
  LinearGradient pageGradient(SurfaceMood mood) => LinearGradient(
    colors: _pageColors(mood),
    stops: _pageStops,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<Color> _lerpColors(
    List<Color> from,
    List<Color> to,
    double progress,
  ) => [
    for (var index = 0; index < from.length; index++)
      Color.lerp(from[index], to[index], progress)!,
  ];

  /// Nothing reads a palette with one colour changed, so there is nothing to
  /// copy it with.
  @override
  AppPalette copyWith() => this;

  /// Every colour eased between the two palettes, so a change of theme moves
  /// with the colours Material eases on its own.
  @override
  AppPalette lerp(covariant AppPalette? other, double progress) {
    if (other == null) return this;
    Color mix(Color from, Color to) => Color.lerp(from, to, progress)!;
    return AppPalette(
      brightness: progress < 0.5 ? brightness : other.brightness,
      page: mix(page, other.page),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceLive: mix(surfaceLive, other.surfaceLive),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      muted: mix(muted, other.muted),
      faint: mix(faint, other.faint),
      accent: mix(accent, other.accent),
      accentDeep: mix(accentDeep, other.accentDeep),
      onAccent: mix(onAccent, other.onAccent),
      premium: mix(premium, other.premium),
      premiumInk: mix(premiumInk, other.premiumInk),
      connected: mix(connected, other.connected),
      connectedInk: mix(connectedInk, other.connectedInk),
      failed: mix(failed, other.failed),
      failedInk: mix(failedInk, other.failedInk),
      warning: mix(warning, other.warning),
      warningInk: mix(warningInk, other.warningInk),
      dialog: mix(dialog, other.dialog),
      sheet: mix(sheet, other.sheet),
      overlay: mix(overlay, other.overlay),
      snack: mix(snack, other.snack),
      onSnack: mix(onSnack, other.onSnack),
      snackFailure: mix(snackFailure, other.snackFailure),
      errorToast: mix(errorToast, other.errorToast),
      noticeToast: mix(noticeToast, other.noticeToast),
      planPremiumRim: mix(planPremiumRim, other.planPremiumRim),
      planBasicRim: mix(planBasicRim, other.planBasicRim),
      planBasicInk: mix(planBasicInk, other.planBasicInk),
      veil: mix(veil, other.veil),
      shadow: mix(shadow, other.shadow),
      schemePrimary: mix(schemePrimary, other.schemePrimary),
      schemeSecondary: mix(schemeSecondary, other.schemeSecondary),
      pageIdle: _lerpColors(pageIdle, other.pageIdle, progress),
      pageBusy: _lerpColors(pageBusy, other.pageBusy, progress),
      pageActive: _lerpColors(pageActive, other.pageActive, progress),
      pageAlert: _lerpColors(pageAlert, other.pageAlert, progress),
    );
  }
}

/// Where a widget reads the palette from.
extension AppPaletteOf on BuildContext {
  /// The palette of the theme this context is drawn in.
  ///
  /// Both of the app's themes carry one. A tree with none — a test that pumps
  /// a bare `MaterialApp` — gets the dark palette the app was designed in.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
