import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// The premium module's colours and motion, in one place.
///
/// These are per-module tokens, not an app-wide dump: every value here is used
/// by more than one premium widget, and the same literals were previously
/// re-declared privately in four files, where they had already started to
/// drift apart.
///
/// Every colour names a role of the [AppPalette] it is built from, so the
/// module follows the theme it is drawn in. Read it once per build with
/// [PremiumPalette.of]. The pass card's own artwork, the alphas and the motion
/// do not change with the theme, so they stay static.
final class PremiumPalette {
  const PremiumPalette(this._core);

  factory PremiumPalette.of(BuildContext context) =>
      PremiumPalette(context.palette);

  final AppPalette _core;

  // --- Accents -------------------------------------------------------------

  /// The module's primary action colour.
  Color get primary => _core.accentDeep;

  /// The tunnel. Used for the config that is currently connected, and — a
  /// step quieter, see [historyAlpha] — for the one connected to last.
  ///
  /// It no longer carries the disconnect affordance beside it: stopping a
  /// tunnel now reads in [red], which is the colour that means stop.
  Color get blue => _core.accent;

  /// How strongly the two connection states are drawn.
  ///
  /// The same hue at two weights rather than two hues: where the tunnel *is*
  /// and where it *was* are the same kind of fact, and the live one has to
  /// outrank the remembered one at a glance.
  static const liveAlpha = 0.45;
  static const historyAlpha = 0.28;

  /// The wash behind the "last connected" badge.
  static const badgeFillAlpha = 0.18;

  /// In flight — a connect that has been asked for and not yet answered.
  Color get amber => _core.warning;

  /// [amber] drawn as a mark rather than a fill: a spinner, a glyph. The fill
  /// reads at under 2:1 on a light card, and this is the same amber in dark.
  Color get amberInk => _core.warningInk;

  /// Destructive: removing a device, signing out, and inline errors in the
  /// account screen.
  Color get red => _core.failedInk;

  /// Destructive as a fill: the button that deletes the account. [red] is ink
  /// and too light to carry a white label.
  Color get redFill => _core.failed;

  // --- Offers --------------------------------------------------------------

  /// What each way of being short of premium is painted with, wherever it is
  /// offered: buying one, renewing a lapsed one, or asking support to restore
  /// a disabled account.
  ///
  /// One home for the three because they are now said in two places — the
  /// dialogs that offer the way out, and the home row that raises them — and a
  /// row whose colour disagreed with the dialog it opened would read as two
  /// different problems rather than one.
  ///
  /// Renewing is amber rather than red on purpose: a lapsed subscription is a
  /// warning with an obvious way out, and the destructive colour is kept for
  /// the one state the user cannot fix alone.
  Color get offerBuy => _core.accent;
  Color get offerRenew => _core.warningInk;
  Color get offerRestore => _core.failedInk;

  // --- Signal strength -----------------------------------------------------

  Color get signalStrong => _core.premiumInk;
  Color get signalWeak => _core.warningInk;
  Color get signalUnreachable => _core.failedInk;

  /// The "last connected" badge, which has to stay legible at 9sp.
  ///
  /// Blue rather than green, with the rest of that badge: green is what this
  /// app says premium with — the plan pill, the offer row, the accents on the
  /// account screen — and where the tunnel has been is a fact about the
  /// connection, not about the subscription. It sits a step lighter than
  /// [blue] so it holds at that size on a fill of the same hue.
  Color get badgeText => _core.connectedInk;

  // --- Paywall -------------------------------------------------------------

  /// The paywall's one accent: Premium's column, the selected plan, the button
  /// that buys it.
  Color get paywallAccent => _core.accent;

  /// How strongly [paywallAccent] tints Premium's column and the selected
  /// plan, and the chips that say what a plan saves.
  static const paywallTintAlpha = 0.10;
  static const paywallChipAlpha = 0.16;

  /// Basic, in the comparison: the muted ink its badge is drawn in. Yellow
  /// means a warning or something in progress everywhere else in the app.
  Color get paywallBasic => _core.planBasicInk;

  /// The plan that costs least a month: the fill of its tag. Amber, as a tag
  /// rather than a state, so it stands out from the green that marks the plan
  /// selected.
  Color get paywallBestValue => _core.warning;

  /// The comparison's little pictures, each in the colour it already means
  /// in the app: amber for the ad and its wait, the tunnel's blue for a
  /// laptop on the connection, premium green for speed and for the phone
  /// Premium adds. The cut-out matches the page, so a shape drawn over
  /// another reads as in front of it. The ad's amber is the ink, because its
  /// ring and its label are marks on the tile, not a fill.
  Color get paywallArtAd => _core.warningInk;
  Color get paywallArtSpeed => _core.accent;
  Color get paywallArtLaptop => _core.connectedInk;
  Color get paywallArtPhone => _core.accent;
  Color get paywallArtCutout => _core.sheet;
  Color get paywallArtTrack => _core.lineStrong;

  /// The marks drawn over the pictures — the strike through the ad, the
  /// gauge's needle. They land on the icon tile as much as on a picture, so
  /// they take the page's neutral: white in dark, the ink in light.
  Color get paywallArtInk => _core.veil;

  /// How far a paywall control dims while it cannot be pressed: the app's
  /// primary button's own rung, so the stepper and the button beside it fade
  /// alike.
  static const disabledAlpha = 0.4;

  // --- Surfaces ------------------------------------------------------------

  /// Opaque surfaces, for the two places that cannot be translucent: a dialog
  /// that must not show the list through itself, and a snackbar over it.
  Color get dialogSurface => _core.dialog;

  /// The sheet the server list rises in.
  Color get sheetSurface => _core.sheet;
  Color get snackSuccess => _core.snack;

  Color get glassHigh => _core.surfaceRaised;
  Color get glassLow => _core.surface;

  /// The square an icon sits in.
  Color get iconBoxHigh => _core.surfaceRaised;
  Color get iconBoxLow => _core.surfaceRaised;
  Color get cardSurface => _core.surfaceRaised;

  /// A card holding the live connection, or the one connected to last.
  Color get cardLive => _core.surfaceLive;
  Color get cardInset => _core.surface;
  Color get border => _core.lineStrong;
  Color get borderSoft => _core.line;
  Color get divider => _core.line;

  // --- Text ----------------------------------------------------------------

  Color get textPrimary => _core.text;
  Color get textSecondary => _core.textSecondary;
  Color get textTertiary => _core.muted;
  Color get textMuted => _core.faint;

  // --- Account tab ---------------------------------------------------------
  //
  // The account tab is drawn on the app's ink with opaque neutrals, so its
  // colours are not shifted by whatever sits behind them.

  /// The tab's ground.
  Color get pageInk => _core.page;

  /// A card, a field, a tile on [pageInk].
  Color get inkSurface => _core.surface;

  /// A field with focus, the segmented control's thumb, a device's glyph box.
  Color get inkSurfaceRaised => _core.surfaceRaised;

  /// The rim of a surface, and a stronger rim for what is raised.
  Color get inkLine => _core.line;
  Color get inkLineStrong => _core.lineStrong;

  /// Text, in three weights.
  Color get inkText => _core.text;
  Color get inkMuted => _core.muted;
  Color get inkFaint => _core.faint;

  /// Live: the subscription is active, a seat is taken, this device.
  Color get good => _core.premiumInk;

  /// Destructive on the account tab: signing out, deleting, removing.
  Color get danger => _core.failedInk;

  /// The account tab's blue: the pass, the primary action, the focused
  /// field. The subscription's own colour, so the pass and the button that
  /// sells it read as one thing. A lit gradient runs from [accent] to
  /// [accentDeep].
  Color get accent => _core.accent;
  Color get accentDeep => _core.accentDeep;

  /// The label on a blue fill.
  Color get onAccent => _core.onAccent;

  /// The blue light in the tab's top corner.
  List<Color> get pageGlow => [
    _core.accent.withValues(alpha: _pageGlowAlpha),
    _core.accent.withValues(alpha: 0),
  ];
  static const _pageGlowAlpha = 0.13;

  /// The faint cool light in the opposite bottom corner, so the ink has depth
  /// rather than reading as a flat fill.
  List<Color> get pageGlowLow => [
    _core.premiumInk.withValues(alpha: _pageGlowLowAlpha),
    _core.premiumInk.withValues(alpha: 0),
  ];
  static const _pageGlowLowAlpha = 0.07;

  // --- The pass ---------------------------------------------------------------
  //
  // The pass is a card of its own colour on either page, so its artwork is
  // fixed.

  /// Pale blue, for the entitled pass's captions.
  static const accentInk = Color(0xFFBFE0FF);

  /// The light that passes over the entitled pass.
  static const sheenLight = Color(0xFFD6ECFF);

  /// The entitled pass: deep navy, lit from its top corner.
  static const passEntitled = <Color>[
    Color(0xFF123A6B),
    Color(0xFF0B1F3D),
    Color(0xFF07101F),
  ];

  /// A lapsed or disabled account's pass: the same card, in red.
  static const passLapsed = <Color>[
    Color(0xFF4A1A1C),
    Color(0xFF241011),
    Color(0xFF140A0B),
  ];

  static const passStops = <double>[0.0, 0.45, 1.0];

  // On a light page the pass is drawn in the accent's own blue and the
  // failed red rather than in navy and near-black. Those were by far the
  // darkest things in the light theme: the card had kept a dark mode of its
  // own on a page that had left it.

  /// The entitled pass on a light page: the accent, lit from its top corner.
  static const passEntitledDay = <Color>[
    Color(0xFF3D8BEA),
    Color(0xFF1563C7),
    Color(0xFF0F4FA3),
  ];

  /// A lapsed or disabled account's pass on a light page.
  static const passLapsedDay = <Color>[
    Color(0xFFE0524F),
    Color(0xFFBA1C1C),
    Color(0xFF8F1616),
  ];

  /// The captions on a day pass. The night pass's pale blue sinks into the
  /// accent's blue, so these are near-white.
  static const passDayCaption = Color(0xFFF2F7FD);

  /// What everything drawn on a day pass reads: the dark palette's roles,
  /// with every ink set in white or the palest tint of its colour, so it
  /// reads on the accent's blue and the failed red alike. The accent itself
  /// is white, so the days left and a renew button stand out of the card
  /// rather than into it.
  static const passDayInk = AppPalette(
    brightness: Brightness.dark,
    page: Color(0xFF0A0D12),
    surface: Color(0xFF11161D),
    surfaceRaised: Color(0xFF171E27),
    surfaceLive: Color(0xFF16233A),
    line: Color(0x26FFFFFF),
    lineStrong: Color(0x40FFFFFF),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xE6FFFFFF),
    muted: Color(0xCCFFFFFF),
    faint: Color(0x99FFFFFF),
    accent: Color(0xFFFFFFFF),
    accentDeep: Color(0xFFE4EEFB),
    onAccent: Color(0xFF0F4FA3),
    premium: Color(0xFF228C46),
    premiumInk: Color(0xFFB8F5E0),
    connected: Color(0xFF2B7FF0),
    connectedInk: Color(0xFF4DA8FF),
    failed: Color(0xFFBA1C1C),
    failedInk: Color(0xFFFFD4D4),
    warning: Color(0xFFF5B83D),
    warningInk: Color(0xFFFFD98A),
    dialog: Color(0xFF171E27),
    sheet: Color(0xFF11161D),
    overlay: Color(0xFF0A0D12),
    snack: Color(0xFF171E27),
    onSnack: Color(0xFFEDF0F4),
    snackFailure: Color(0xFF2A1719),
    errorToast: Color(0xFF241417),
    noticeToast: Color(0xFF231E12),
    planPremiumRim: Color(0x73FFFFFF),
    planBasicRim: Color(0x40FFFFFF),
    planBasicInk: Color(0xCCFFFFFF),
    veil: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    schemePrimary: Color(0xFF1B1A20),
    schemeSecondary: Color(0xFF2F2E35),
    pageIdle: [Color(0xFF0D131C), Color(0xFF0A0D12), Color(0xFF080A0E)],
    pageBusy: [Color(0xFF19150C), Color(0xFF0B0D11), Color(0xFF090A0D)],
    pageActive: [Color(0xFF0B1A2E), Color(0xFF0A0D12), Color(0xFF080A0E)],
    pageAlert: [Color(0xFF1B0F12), Color(0xFF0B0C10), Color(0xFF090A0D)],
  );

  /// Whether this palette is a light page's, which the pass is drawn
  /// brighter on.
  bool get onLightPage => _core.brightness == Brightness.light;

  /// The open pass's rings: barely there.
  static const passRingQuiet = Color(0x0FD6E2F0);

  static const passRimAlpha = 0.32;

  /// The four rings in the pass's corner, outermost first.
  static const passRingAlphas = <double>[0.18, 0.24, 0.30, 0.38];
  static const passSheenAlpha = 0.16;
  static const passLabelAlpha = 0.75;
  static const passCaptionAlpha = 0.70;
  static const passDateCaptionAlpha = 0.60;
  static const chipFillAlpha = 0.10;
  static const chipRimAlpha = 0.22;
  static const pressAlpha = 0.10;
  static const dimmedAlpha = 0.5;
  static const fieldFocusAlpha = 0.55;
  static const emblemOuterAlpha = 0.28;
  static const emblemInnerAlpha = 0.45;
  static const dangerRestAlpha = 0.85;
  static const dangerPressAlpha = 0.08;

  /// The light crosses the entitled pass in [sheenSweep], once every
  /// [sheenCycle].
  static const sheenSweep = Duration(milliseconds: 2400);
  static const sheenCycle = Duration(milliseconds: 6000);

  // --- Motion --------------------------------------------------------------

  /// A state change on something already on screen: a card highlighting, a
  /// chevron turning, a section expanding.
  static const stateChange = Duration(milliseconds: 200);

  /// One widget replacing another in place, which needs a beat longer than a
  /// state change to read as a swap rather than a flicker.
  static const swap = Duration(milliseconds: 280);

  /// Content arriving — a list or a header settling in after a load.
  static const entrance = Duration(milliseconds: 420);
}

/// The account screen's colour, chosen by what the account is.
///
/// One object rather than four separate lookups so a state can never be
/// half-applied — a blue crown over a green button, say.
class PremiumAccent {
  const PremiumAccent._({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.onPrimary,
  });

  /// The accent as ink: status text, a glyph, a progress arc, an outline —
  /// and the fill of the one filled button, which carries [onPrimary].
  final Color primary;

  /// The deep tone of the same family, for the far end of a gradient and for
  /// a second status that must not compete with [primary].
  final Color secondary;

  final Color icon;

  /// Foreground on top of [primary]: whichever ink reads on it.
  final Color onPrimary;

  /// Blue: nobody is signed in, or nothing has been bought yet, and the
  /// screen is selling the subscription.
  factory PremiumAccent.signedOut(PremiumPalette palette) => PremiumAccent._(
    primary: palette.accent,
    secondary: palette.accentDeep,
    icon: palette.accent,
    onPrimary: palette.onAccent,
  );

  /// Green: signed in and entitled.
  factory PremiumAccent.entitled(PremiumPalette palette) => PremiumAccent._(
    primary: palette._core.premiumInk,
    secondary: palette._core.premium,
    icon: palette._core.premiumInk,
    onPrimary: AppPalette.labelOn(palette._core.premiumInk),
  );

  /// Red: signed in, but the subscription has lapsed or the account is
  /// disabled. This is the one state where the screen has bad news.
  ///
  /// The label is whichever ink reads on [primary]: on the on-dark red that is
  /// the dark one, which measures 7:1 where white measures 2.7:1.
  factory PremiumAccent.notEntitled(PremiumPalette palette) => PremiumAccent._(
    primary: palette._core.failedInk,
    secondary: palette._core.failed,
    icon: palette._core.failedInk,
    onPrimary: AppPalette.labelOn(palette._core.failedInk),
  );
}
