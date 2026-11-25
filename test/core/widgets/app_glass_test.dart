import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const palette = AppPalette.dark;

  group('AppGlass', () {
    test("should draw a panel in the palette's surface and line", () {
      final style = AppGlass.panel(palette, cornerRadius: 0);

      expect(style.color, palette.surface);
      expect(style.borderColor, palette.line);
    });

    test("should raise a chip in the palette's raised surface", () {
      final style = AppGlass.chip(palette, cornerRadius: 0);

      expect(style.color, palette.surfaceRaised);
    });

    test("should cast the palette's shadow under a dialog", () {
      final style = AppGlass.dialog(palette, cornerRadius: 0);

      expect(style.color, palette.dialog);
      expect(style.boxShadow!.single.color.r, palette.shadow.r);
    });

    test('should rim a home surface in the colour it is given', () {
      const rim = Color(0xFF123456);
      final style = AppGlass.homeSurface(
        palette,
        cornerRadius: 0,
        borderColor: rim,
      );

      expect(style.color, palette.surface);
      expect(style.borderColor, rim);
    });
  });
}
