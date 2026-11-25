import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:begzar/core/theme/brand_assets.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/glass_bird.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tall enough that an edge a point or so wide is several pixels, so the light
/// shows up in the pixels rather than in the rounding.
const _height = 200.0;

/// The share of the body, taken along the line the light travels, that
/// counts as near the light at one end and as far from it at the other.
const _bodyThird = 1 / 3;

/// How solid the body must be, on average, in the third nearest the light.
///
/// An outline drawn on the dial, which is what the bird was before it was
/// filled, measures about 0.3 here and the bird as built about 0.7; this sits
/// midway, so a bird thinned back to an outline fails and tuning the fill a
/// little either way does not.
const _minimumNearOpacity = 0.5;

/// How solid the body may be, on average, in the third farthest from the
/// light.
///
/// The bird as built measures about 0.49 here, and the same bird filled solid
/// right across, with the far side lit at more than half strength, about
/// 0.68; this sits midway, so a bird that stops showing the dial through
/// fails.
const _maximumFarOpacity = 0.58;

/// How far, in pixels, a pixel has to sit inside the outline to count as
/// body rather than edge: more than the widest edge the bird draws at
/// [_height].
const _edgeClearance = 4;

/// Marks the layer reference so it is not mistaken for the bird's own
/// boundary.
const _layerKey = ValueKey('artwork layer');

/// Decodes both layers of the artwork into the image cache, so a bird mounted
/// afterwards finds them there and paints on its first frame.
///
/// Done outside the test's fake clock: decoding is real work the engine does
/// on its own time.
Future<void> _decodeArtwork(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final asset in [BrandAssets.bird, BrandAssets.birdAccent]) {
      final decoded = Completer<void>();
      final stream = AssetImage(asset).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((_, _) {
        if (!decoded.isCompleted) decoded.complete();
      });
      stream.addListener(listener);
      await decoded.future;
      stream.removeListener(listener);
    }
  });
}

/// Mounts the bird in the language [direction] stands in for, with its
/// artwork already decoded.
Future<void> _pumpBird(WidgetTester tester, TextDirection direction) async {
  await _decodeArtwork(tester);
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: const Center(
        child: GlassBird(
          height: _height,
          light: MainPalette.dialAtRest,
          glow: 0,
        ),
      ),
    ),
  );
}

/// The bird as it reached the screen, premultiplied, one RGBA quad a pixel.
Future<({Uint8List pixels, int width, int height})> _render(
  WidgetTester tester,
) async {
  late ({Uint8List pixels, int width, int height}) rendered;

  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(GlassBird),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered = (
      pixels: data!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  });

  return rendered;
}

/// One layer of the artwork drawn plain, at the size and place the bird
/// draws it in a left-to-right screen, as alpha a pixel.
///
/// [size] is the bird's own painted size, read off the bird before this is
/// called.
Future<Uint8List> _renderLayer(
  WidgetTester tester,
  String asset,
  Size size,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: _layerKey,
          child: FractionalTranslation(
            translation: BrandAssets.birdOpticalCentring,
            child: Image.asset(
              asset,
              width: size.width,
              height: size.height,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  late Uint8List alpha;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_layerKey),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = data!.buffer.asUint8List();
    alpha = Uint8List(image.width * image.height);
    for (var index = 0; index < alpha.length; index++) {
      alpha[index] = pixels[index * 4 + 3];
    }
  });

  return alpha;
}

/// How solid the bird's body is drawn, on average, near the light and far
/// from it, in a left-to-right screen where the light enters at the top left.
///
/// Only body counts: a pixel the outline covers fully, at least
/// [_edgeClearance] from any pixel it does not, and outside the streaks,
/// which are drawn solid whatever the body does.
Future<({double near, double far})> _bodyOpacity(WidgetTester tester) async {
  await _pumpBird(tester, TextDirection.ltr);
  final size = tester.getSize(
    find.descendant(
      of: find.byType(GlassBird),
      matching: find.byType(CustomPaint),
    ),
  );
  final bird = await _render(tester);
  final outline = await _renderLayer(tester, BrandAssets.bird, size);
  final streaks = await _renderLayer(tester, BrandAssets.birdAccent, size);

  final width = bird.width;
  final height = bird.height;
  bool solidOutline(int column, int row) =>
      column >= 0 &&
      row >= 0 &&
      column < width &&
      row < height &&
      outline[row * width + column] == 255;
  bool isBody(int column, int row) {
    if (streaks[row * width + column] != 0) return false;
    for (final dx in [-_edgeClearance, 0, _edgeClearance]) {
      for (final dy in [-_edgeClearance, 0, _edgeClearance]) {
        if (!solidOutline(column + dx, row + dy)) return false;
      }
    }
    return true;
  }

  // How far each body pixel sits along the line the light travels, corner to
  // corner across the bird: only the order matters, so it is left unscaled.
  final body = <({double along, double opacity})>[
    for (var row = 0; row < height; row++)
      for (var column = 0; column < width; column++)
        if (isBody(column, row))
          (
            along: (column * width + row * height).toDouble(),
            opacity: bird.pixels[(row * width + column) * 4 + 3] / 255,
          ),
  ]..sort((first, second) => first.along.compareTo(second.along));

  expect(body, isNotEmpty, reason: 'the bird has a body to measure');
  final third = (body.length * _bodyThird).floor();
  double meanOpacity(Iterable<({double along, double opacity})> pixels) =>
      pixels.fold(0.0, (sum, pixel) => sum + pixel.opacity) / third;

  return (
    near: meanOpacity(body.take(third)),
    far: meanOpacity(body.skip(body.length - third)),
  );
}

void main() {
  group('GlassBird', () {
    // The bird is the brand's mark, and a mark keeps one shape whichever way
    // the screen reads, so a right-to-left screen draws it pixel for pixel
    // as a left-to-right one does: facing, centring and light alike.
    testWidgets('draws the same bird in either direction', (tester) async {
      await _pumpBird(tester, TextDirection.ltr);
      final leftToRight = await _render(tester);
      await _pumpBird(tester, TextDirection.rtl);
      final rightToLeft = await _render(tester);

      expect(
        rightToLeft.pixels,
        leftToRight.pixels,
        reason: 'the bird is not mirrored for a right-to-left screen',
      );
    });

    testWidgets('centres itself by its weight rather than its box', (
      tester,
    ) async {
      double offCentre() =>
          tester
              .getCenter(
                find.descendant(
                  of: find.byType(GlassBird),
                  matching: find.byType(CustomPaint),
                ),
              )
              .dx -
          tester.getCenter(find.byType(Center)).dx;

      await _pumpBird(tester, TextDirection.ltr);
      expect(
        offCentre(),
        greaterThan(0),
        reason:
            'the wings and tail pull the weight left, so the box sits right '
            'of centre',
      );

      await _pumpBird(tester, TextDirection.rtl);
      expect(
        offCentre(),
        greaterThan(0),
        reason: 'the shift stays with the bird, which does not turn round',
      );
    });

    // The bird is glass with weight to it: the light fills the body where it
    // enters, so the bird reads as a solid shape on the dial rather than as an
    // outline drawn on it.
    testWidgets('draws its body near solid where the light enters', (
      tester,
    ) async {
      final opacity = await _bodyOpacity(tester);

      expect(opacity.near, greaterThan(_minimumNearOpacity));
    });

    // And it is still glass: the light thins out across the body, so the dial
    // shows through it on the side away from the light.
    testWidgets('lets the dial show through on the far side', (tester) async {
      final opacity = await _bodyOpacity(tester);

      expect(opacity.far, lessThan(_maximumFarOpacity));
      expect(
        opacity.far,
        lessThan(opacity.near),
        reason: 'clearer away from the light than near it',
      );
    });
  });
}
