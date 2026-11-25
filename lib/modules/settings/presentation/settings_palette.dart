import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter/material.dart';

/// The settings module's colours, shapes and motion, in one place.
///
/// These are per-module tokens, not an app-wide dump: every value here is
/// used by more than one settings widget, and each colour names a role of the
/// [AppPalette] it is built from, so the module follows the theme it is drawn
/// in.
///
/// Read it once per build with [SettingsPalette.of]. What does not change with
/// the theme stays static.
final class SettingsPalette {
  const SettingsPalette(this._core);

  factory SettingsPalette.of(BuildContext context) =>
      SettingsPalette(context.palette);

  final AppPalette _core;

  // --- Accents -------------------------------------------------------------

  /// The module's primary action colour: an enabled switch, the save button,
  /// the destructive "clear all" text. The account tab's blue, so the two
  /// tabs read as one app.
  Color get accent => _core.accent;

  /// Foreground on top of [accent].
  Color get onAccent => _core.onAccent;

  /// Input that cannot be accepted. Warm rather than the destructive red:
  /// the user is still editing, and nothing has been lost.
  Color get invalidInput => _core.failedInk;

  // --- Ground --------------------------------------------------------------

  /// The settings screens' ground: the account tab's ink, with the same blue
  /// light in the top corner.
  Color get pageInk => _core.page;
  BoxDecoration get pageGlow => BoxDecoration(
    gradient: RadialGradient(
      center: const AlignmentDirectional(0.9, -1.1),
      radius: 1.1,
      colors: [
        _core.accent.withValues(alpha: _pageGlowAlpha),
        _core.accent.withValues(alpha: 0),
      ],
    ),
  );
  static const _pageGlowAlpha = 0.13;

  // --- Surfaces ------------------------------------------------------------
  //
  // Opaque on [pageInk] rather than glass over a gradient, so a card is the
  // same colour wherever it sits.

  /// The opaque sheet the routing screen raises.
  Color get sheetSurface => _core.sheet;

  /// A dropdown's menu, which opens over the rows below it: a settings card,
  /// rimmed in [border] and lifted by its shadow. The card's own surface
  /// rather than the dialog's, which is [cardRaised]'s colour in dark, so an
  /// entry's icon tile stands off the menu as it does off any settings row.
  Color get menuSurface => _core.surface;

  /// What the menu casts on the rows under it.
  Color get menuShadow => _core.shadow;

  /// A menu row being pressed, hovered or reached by the keyboard: a wash of
  /// the accent, the colour of the selected thing, never Material's grey.
  Color get menuPress => _core.accent.withValues(alpha: _menuPressAlpha);
  static const _menuPressAlpha = 0.10;

  Color get card => _core.surface;

  /// A shape raised on [card]: a row's glyph tile, the selected tab.
  Color get cardRaised => _core.surfaceRaised;
  Color get cardInset => _core.page;

  /// The chosen row in a list or a menu. Stronger on a light page, where the
  /// card is near white and a thin wash of the accent barely shows.
  Color get selectedRow => _core.accent.withValues(
    alpha: _core.brightness == Brightness.light
        ? _selectedRowLightAlpha
        : _selectedRowAlpha,
  );
  static const _selectedRowLightAlpha = 0.12;
  Color get border => _core.lineStrong;
  Color get borderSoft => _core.line;
  Color get divider => _core.line;
  static const _selectedRowAlpha = 0.07;

  // --- Controls ------------------------------------------------------------

  Color get switchTrackOn => _core.accent.withValues(alpha: _switchTrackAlpha);
  Color get switchThumbOff => _core.muted;
  Color get switchTrackOff => _core.surfaceRaised;
  static const _switchTrackAlpha = 0.45;

  /// Applied to a whole row whose switch is off but which is still shown,
  /// so the row reads as unavailable without disappearing.
  static const disabledOpacity = 0.45;

  // --- Text ----------------------------------------------------------------

  Color get textPrimary => _core.text;
  Color get textSecondary => _core.textSecondary;
  Color get textTertiary => _core.muted;
  Color get textMuted => _core.faint;

  /// A section's title, over its card.
  Color get sectionLabel => textTertiary;

  /// Glyphs inside a tile's icon tile.
  Color get icon => textPrimary;

  /// The chevron at the end of a row that opens something.
  Color get chevron => textMuted;

  /// The wash behind a mark drawn in a routing action's colour: a routing
  /// rule's glyph tile, an app's VPN or Direct tag.
  static Color actionTint(Color action) =>
      action.withValues(alpha: _actionTintAlpha);
  static const _actionTintAlpha = 0.18;

  // --- First-run language screen -------------------------------------------

  /// The mark on the first-run language screen, and the disc it sits on.
  ///
  /// The permission gate's blue rather than [accent]: the two screens follow
  /// each other on a first launch, and a yellow mark then a blue one would
  /// read as two unrelated screens.
  Color get firstRunMark => _core.connected;
  Color get firstRunMarkFill =>
      firstRunMark.withValues(alpha: _firstRunMarkFillAlpha);
  static const _firstRunMarkFillAlpha = 0.15;

  /// The continue button, in the same blue as [firstRunMark] and as the
  /// permission gate's own button, for the same reason. Its label is the light
  /// one a deep fill takes, as that button's is.
  Color get firstRunAction => firstRunMark;
  Color get onFirstRunAction => AppPalette.labelOn(firstRunAction);

  // --- Motion --------------------------------------------------------------

  /// The background gradient following a connection-status change.
  static const backgroundShift = Duration(milliseconds: 200);
}

/// What a routing action means, in colour.
///
/// Green lets traffic past, red stops it, blue sends it through the tunnel —
/// the same three meanings the connection status uses elsewhere, and now the
/// same three colours. They used to be a separate set of Material tints that
/// only resembled them.
extension RoutingActionColor on RoutingAction {
  Color colorIn(SettingsPalette palette) => switch (this) {
    RoutingAction.direct => palette._core.premiumInk,
    RoutingAction.block => palette._core.failedInk,
    RoutingAction.proxy => palette._core.connectedInk,
  };
}
