import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Telegram's plane, drawn rather than borrowed from the icon font.
///
/// Iconsax has no Telegram glyph. Every affordance that opens `t.me` used
/// `send_2` instead — a generic paper plane, which says "submit" rather than
/// naming where the tap goes. On a button whose label already reads *Buy
/// Premium* that is only redundant; on a bare "Get help" link, which is the
/// one way out of a failure, the mark is the fastest thing on screen to
/// recognise and it was saying the wrong thing.
///
/// A painter rather than an asset: it takes its colour from whoever draws it,
/// stays sharp at any size, needs no density variants, and adds no dependency
/// for a single glyph.
///
/// It does not turn around in Persian, and should not be made to. The app's
/// own bird does — see `ConnectionDial` — because that is Begzar's artwork
/// and it belongs facing the way the screen is read. This one is somebody
/// else's mark, and a mirrored logo is no longer the logo: Telegram itself
/// points the same way in every locale, which is what makes it recognisable
/// in the half second a stuck user gives it.
class TelegramMark extends StatelessWidget {
  const TelegramMark({super.key, required this.size, this.color});

  /// The side of the square the mark is drawn inside — the same number an
  /// [Icon] would be given, so the two can be swapped at a call site without
  /// re-measuring the row around them.
  final double size;

  /// Defaults to the ambient icon colour, which is what [Icon] does and what
  /// lets a button's `foregroundColor` reach it.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TelegramMarkPainter(
          color ?? IconTheme.of(context).color ?? context.palette.veil,
        ),
      ),
    );
  }
}

class _TelegramMarkPainter extends CustomPainter {
  const _TelegramMarkPainter(this.color);

  final Color color;

  /// The box the vertices below are measured in, which is the 24-unit grid
  /// every Iconsax glyph is drawn on. Sharing it is what lets a mark and an
  /// icon given the same `size` come out the same weight.
  static const _grid = 24.0;

  /// The plane, walked from the nose.
  ///
  /// Six points, and the fifth is the one doing the work: it lifts the bottom
  /// edge into the notch that separates this from any other paper plane. Take
  /// it away and what is left is a swept triangle that reads as `send_2`
  /// again.
  ///
  /// Deliberately no interior crease. The fold only exists in the two-colour
  /// lockup, where it is a shade rather than a line — drawing it into a
  /// single-colour glyph would mean a sliver of negative space narrower than
  /// a physical pixel at the size the help links use, which fills in and
  /// reads as a smudge rather than as a fold.
  static const _plane = <Offset>[
    Offset(22.6, 2.8), // the nose, where the sheet is pinched
    Offset(1.9, 11.0), // the far tip of the sweep
    Offset(7.6, 13.1), // where the wing folds down
    Offset(9.5, 19.4), // the wing's own tip
    Offset(12.4, 16.2), // the notch
    Offset(17.6, 20.0), // the trailing corner
  ];

  /// Where the mark looks centred, in grid units, measured off [_plane].
  ///
  /// Halfway between the two things "centre" can mean for a shape like this,
  /// because on its own each is wrong in a different direction:
  ///
  /// * Where the ink *balances* — the area centroid, `(14.01, 11.41)`. The
  ///   plane is swept, so most of its area is the wide body up and to the
  ///   right while the tail is long and thin. Balancing on area pays the tail
  ///   almost no attention and pushes the shape left; on device that left a
  ///   visible six pixels more gap on the right of the appbar button than on
  ///   the left.
  /// * Where the ink *spans* — the bounding box's middle, `(12.25, 11.40)`.
  ///   That treats the tail's last thin point as equal to the body and drifts
  ///   the other way.
  ///
  /// Vertically the two agree to within a hundredth of a unit, so the split
  /// only matters across.
  ///
  /// The painter carries this rather than each call site. What it replaced —
  /// a private `Offset(-1, 1)` inside the appbar button — was tuned for one
  /// glyph at one size, and the other five places drew theirs uncorrected.
  static const _opticalCentre = Offset(13.13, 11.41);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    final correction = (Offset(_grid, _grid) / 2 - _opticalCentre) * scale;

    canvas.drawPath(
      Path()..addPolygon([
        for (final vertex in _plane) vertex * scale + correction,
      ], true),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_TelegramMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
