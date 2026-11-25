import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// The update dialog's and the update dot's colours.
///
/// A module palette rather than constants on the widget, for the same reason
/// every other module has one: the next `app_update` surface has to be able to
/// reach these without copying them out of a widget file.
///
/// Everything here sits on one dialog panel, so the neutrals are the page's
/// own neutral — or, for the one recessed surface, the shade — at low alpha
/// rather than fixed greys. Read it once per build with [AppUpdatePalette.of].
final class AppUpdatePalette {
  const AppUpdatePalette(this._core);

  factory AppUpdatePalette.of(BuildContext context) =>
      AppUpdatePalette(context.palette);

  final AppPalette _core;

  // --- Accents ---------------------------------------------------------------

  /// The dialog's action colour: the header ring, the step badge between the
  /// two versions, the required-version tile, and the update button.
  Color get accent => _core.accent;

  /// The dark end of the button and header-ring ramps.
  Color get accentDeep => _core.accentDeep;

  /// The update button's glyph and label: white, because the ramp under it is
  /// a blue in either theme.
  static const onButton = AppPalette.lift;

  /// The glyph in the header ring, which is only a tint of the accent and so
  /// takes the page's own neutral.
  Color get ringGlyph => _core.veil;

  /// The installed version — the thing that is wrong, but not an error.
  ///
  /// Amber rather than the destructive red on purpose: being a build behind
  /// is a warning with an obvious way out, and this dialog already offers it.
  Color get warn => _core.warningInk;

  /// The dot announcing a newer release, on the settings tab and on the row
  /// that offers it.
  ///
  /// Not [accent]: that blue belongs to the forced dialog, and an optional
  /// release is not that kind of news.
  Color get notice => _core.warning;

  // --- Text ------------------------------------------------------------------

  /// The dialog's title and its supporting lines.
  Color get text => _core.text;
  Color get textMuted => _core.muted;

  /// The description under the title, and the muted tile's version number.
  static const descriptionAlpha = 0.95;
  static const mutedVersionAlpha = 0.85;

  // --- The header mark -------------------------------------------------------

  Color get ringTop => accent.withValues(alpha: _ringTopAlpha);
  Color get ringBottom => accentDeep.withValues(alpha: _ringBottomAlpha);
  Color get ringBorder => accent.withValues(alpha: _ringBorderAlpha);
  static const _ringTopAlpha = 0.28;
  static const _ringBottomAlpha = 0.18;
  static const _ringBorderAlpha = 0.45;

  // --- Surfaces inside the panel ---------------------------------------------

  /// The version card. Recessed rather than raised — the shade at low alpha,
  /// not the page's neutral — because it is the one surface here that reads
  /// as a well cut into the panel rather than a card resting on it.
  ///
  /// On a light dialog the shade turns the well a heavy grey and pulls its
  /// labels to about 3:1, so there the page's own grey recesses it instead.
  Color get card => switch (_core.brightness) {
    Brightness.dark => AppPalette.shade.withValues(alpha: _cardAlpha),
    Brightness.light => _core.page,
  };
  static const _cardAlpha = 0.22;

  Color get cardBorder => _core.veil.withValues(alpha: _hairlineAlpha);
  Color get divider => _core.veil.withValues(alpha: _hairlineAlpha);
  static const _hairlineAlpha = 0.08;

  /// The current-version tile, which is stated and not offered.
  Color get mutedFill => _core.veil.withValues(alpha: _mutedFillAlpha);
  Color get mutedBorder => _core.veil.withValues(alpha: _mutedBorderAlpha);
  static const _mutedFillAlpha = 0.04;
  static const _mutedBorderAlpha = 0.06;

  /// The required-version tile, keyed off [accent] so it reads as the target.
  static const activeFillAlpha = 0.10;
  static const activeBorderAlpha = 0.28;

  /// The rounded square each version's icon sits in — a step stronger on the
  /// active tile than the muted one, so the pair reads as now versus next.
  static const iconBoxAlpha = 0.18;
  static const iconBoxMutedAlpha = 0.12;

  /// The circle carrying the arrow between the two versions.
  static const stepBadgeAlpha = 0.15;

  // --- Feedback --------------------------------------------------------------

  /// The snackbar raised when the update page will not open. Opaque, because
  /// it is drawn over a dialog and must not show it through itself.
  Color get snackFailure => _core.snackFailure;
}
