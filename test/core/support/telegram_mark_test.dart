import 'dart:ui' as ui;

import 'package:begzar/core/support/telegram_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Side of the box the mark is rendered into for these tests.
///
/// Larger than any size the app draws it at, so a centring error of a fraction
/// of a point at 14 or 18 shows up here as several whole pixels.
const _renderSize = 96.0;

/// How far off centre the ink may sit, in pixels of a [_renderSize] box.
///
/// Antialiasing and the rasteriser's own rounding move it a little; anything
/// past this is the geometry being wrong rather than the renderer.
const _tolerance = 1.5;

/// The two places a shape like this can be said to sit: where its ink
/// balances (area centroid) and where its ink spans (bounding box middle).
///
/// Both are measured off the rasterised pixels rather than off the painter's
/// own vertex list, so it cannot pass by agreeing with itself.
Future<({Offset balance, Offset span})> _inkCentres(WidgetTester tester) async {
  late Offset balance;
  late Offset span;

  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = data!.buffer.asUint8List();

    var weight = 0.0;
    var x = 0.0;
    var y = 0.0;
    var left = image.width.toDouble();
    var right = 0.0;
    var top = image.height.toDouble();
    var bottom = 0.0;

    for (var row = 0; row < image.height; row++) {
      for (var column = 0; column < image.width; column++) {
        final alpha = pixels[(row * image.width + column) * 4 + 3] / 255;
        if (alpha == 0) continue;
        weight += alpha;
        x += column * alpha;
        y += row * alpha;
        // Half coverage or better, so an antialiased fringe does not stretch
        // the span by a pixel on every side.
        if (alpha < 0.5) continue;
        left = left < column ? left : column.toDouble();
        right = right > column ? right : column.toDouble();
        top = top < row ? top : row.toDouble();
        bottom = bottom > row ? bottom : row.toDouble();
      }
    }

    expect(weight, greaterThan(0), reason: 'the mark drew nothing at all');
    balance = Offset(x / weight, y / weight);
    span = Offset((left + right) / 2, (top + bottom) / 2);
    image.dispose();
  });

  return (balance: balance, span: span);
}

Future<void> _pumpMark(WidgetTester tester, {Color? color}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          child: TelegramMark(size: _renderSize, color: color),
        ),
      ),
    ),
  );
}

void main() {
  group('the mark centres its own ink', () {
    // The plane is swept, so the two readings of "centre" disagree across the
    // box: the wide body pulls the balance point right of where the ink spans.
    // The painter aims for the midpoint of the two — either one alone reads
    // visibly off on device, which is what the hand-tuned `Offset(-1, 1)` in
    // the appbar button was compensating for, at one size, for one glyph.
    testWidgets('the two readings of centre straddle the box centre', (
      tester,
    ) async {
      await _pumpMark(tester, color: const Color(0xFFFFFFFF));

      final ink = await _inkCentres(tester);
      final middle = _renderSize / 2;

      expect(
        ink.balance.dx > middle,
        isTrue,
        reason: 'the body should sit right of centre',
      );
      expect(
        ink.span.dx < middle,
        isTrue,
        reason: 'the tail should reach left of centre',
      );
    });

    testWidgets('their midpoint lands on the middle of the box', (
      tester,
    ) async {
      await _pumpMark(tester, color: const Color(0xFFFFFFFF));

      final ink = await _inkCentres(tester);
      final optical = (ink.balance + ink.span) / 2;

      expect((optical.dx - _renderSize / 2).abs(), lessThan(_tolerance));
      expect((optical.dy - _renderSize / 2).abs(), lessThan(_tolerance));
    });

    testWidgets('neither reading drifts far from it on its own', (
      tester,
    ) async {
      await _pumpMark(tester, color: const Color(0xFFFFFFFF));

      final ink = await _inkCentres(tester);
      // Under a twentieth of the box either way. Past that the correction has
      // stopped being a nudge and the mark reads as off-centre whichever way
      // you measure it.
      const drift = _renderSize / 20;

      for (final reading in [ink.balance, ink.span]) {
        expect((reading.dx - _renderSize / 2).abs(), lessThan(drift));
        expect((reading.dy - _renderSize / 2).abs(), lessThan(drift));
      }
    });

    testWidgets('it stays inside the box it was given', (tester) async {
      await _pumpMark(tester, color: const Color(0xFFFFFFFF));

      expect(
        tester.getSize(find.byType(TelegramMark)),
        const Size(_renderSize, _renderSize),
      );
    });
  });

  group('it takes its colour like an icon does', () {
    testWidgets('an explicit colour wins', (tester) async {
      await _pumpMark(tester, color: const Color(0xFF7FC7FF));

      expect(
        tester.widget<TelegramMark>(find.byType(TelegramMark)).color,
        const Color(0xFF7FC7FF),
      );
    });

    testWidgets('without one it falls back to the ambient icon theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: IconTheme(
            data: IconThemeData(color: Color(0xFF228C46)),
            child: Center(
              child: RepaintBoundary(child: TelegramMark(size: _renderSize)),
            ),
          ),
        ),
      );

      // Nothing to read off the widget — the fallback happens inside build —
      // so this asserts the ink is actually that green rather than the
      // painter's own white default.
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final pixels = data!.buffer.asUint8List();

        // The middle of the box is inside the plane's body, so it is opaque
        // ink rather than an antialiased edge.
        final middle =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;

        expect(pixels[middle], 0x22);
        expect(pixels[middle + 1], 0x8C);
        expect(pixels[middle + 2], 0x46);
        image.dispose();
      });
    });
  });
}
