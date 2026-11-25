import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/main/domain/ping_quality.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = AppPalette.dark;
  const palette = MainPalette(core);

  group('MainPalette', () {
    test('should draw the dial at rest in slate', () {
      expect(MainPalette.dialAtRest, const Color(0xFF7892B6));
    });

    test('should colour a failed connect in the failure ink', () {
      expect(palette.failedInk, core.failedInk);
    });

    test('should take its text from the core palette', () {
      expect(palette.textPrimary, core.text);
      expect(palette.textTertiary, core.muted);
    });

    // Nothing frosts what passes under the bar, so a see-through fill would
    // show the rows behind it sharp, through its icons.
    test('should fill the nav bar solid in both themes', () {
      expect(palette.navFill, isSameColorAs(core.surfaceRaised));
      expect(
        const MainPalette(AppPalette.light).navFill,
        isSameColorAs(AppPalette.light.surfaceRaised),
      );
    });

    test('should film the dial in its light over a dark page', () {
      final stops = palette.dialStops(MainPalette.dialAtRest);

      expect(stops.first.a, closeTo(0.24, 0.01));
      expect(stops.last.a, closeTo(0.08, 0.01));
    });

    test('should draw the dial at rest as a solid disc in light', () {
      const light = MainPalette(AppPalette.light);
      final stops = light.dialStops(MainPalette.dialAtRest);

      expect(stops.map((stop) => stop.a), everyElement(1.0));
    });
  });

  group('PingQualityColor', () {
    test('should paint a healthy reading in the premium ink', () {
      expect(PingQuality.good.colorIn(palette), core.premiumInk);
    });

    test('should paint a poor reading in the failure ink', () {
      expect(PingQuality.poor.colorIn(palette), core.failedInk);
    });
  });
}
