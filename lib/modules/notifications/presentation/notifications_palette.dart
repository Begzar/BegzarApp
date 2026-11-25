import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/surface_alpha.dart';
import 'package:flutter/material.dart';

/// The notifications module's colours, in one place.
///
/// A module palette rather than values written into the gate widget, for the
/// same reason every other module has one. This module had none at all: the
/// permission gate — the first screen a new install sees — painted itself out
/// of a hand-copied gradient, a blue no other screen uses and a title size
/// that is not a step on the type ramp.
///
/// Everything here sits on the same page gradient every other screen paints,
/// so the neutrals are the page's own neutral at an alpha from
/// [SurfaceAlpha]. Read it once per build with [NotificationsPalette.of].
final class NotificationsPalette {
  const NotificationsPalette(this._core);

  factory NotificationsPalette.of(BuildContext context) =>
      NotificationsPalette(context.palette);

  final AppPalette _core;

  /// The mark at the top of the gate, and the button under it: the tunnel's
  /// blue, which is what this app's one primary action has always been drawn
  /// in everywhere else.
  Color get accent => _core.connected;

  /// The button's label: whichever ink reads on the blue.
  Color get onAccent => AppPalette.labelOn(accent);

  /// The disc the bell sits on: a wash of the accent, so the pair reads as
  /// one mark rather than a glyph on a circle.
  Color get markFill => accent.withValues(alpha: _markFillAlpha);
  static const _markFillAlpha = 0.15;

  Color get textPrimary => _core.veil;
  Color get textSecondary =>
      _core.veil.withValues(alpha: SurfaceAlpha.textSecondary);

  /// The line under the button explaining where the reader has to go when the
  /// system will not ask again.
  Color get textTertiary =>
      _core.veil.withValues(alpha: SurfaceAlpha.textTertiary);
}
