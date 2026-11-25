import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = AppPalette.dark;
  const palette = PremiumPalette(core);

  group('PremiumPalette', () {
    test("should read the account tab's ground from the core palette", () {
      expect(palette.pageInk, core.page);
      expect(palette.inkText, core.text);
    });

    test('should keep the pass card navy in either theme', () {
      expect(PremiumPalette.passEntitled.first, const Color(0xFF123A6B));
    });

    test('should paint a lapsed renewal in the warning ink', () {
      expect(palette.offerRenew, core.warningInk);
    });
  });

  group('PremiumPalette in light', () {
    const lightCore = AppPalette.light;
    const light = PremiumPalette(lightCore);

    // The amber fill reads at under 2:1 as a mark on a light card.
    test('should draw amber marks in the warning ink', () {
      expect(light.amberInk, lightCore.warningInk);
      expect(palette.amberInk, core.warning);
    });

    // The marks sit on the icon tile, not on a fill of their own, so white
    // vanished on the light one.
    test('should draw the paywall pictures\' marks in the page ink', () {
      expect(light.paywallArtInk, lightCore.veil);
      expect(light.paywallArtAd, lightCore.warningInk);
      expect(palette.paywallArtInk, AppPalette.lift);
    });
  });

  group('PremiumAccent', () {
    test('should sell the subscription in the accent', () {
      final accent = PremiumAccent.signedOut(palette);

      expect(accent.primary, core.accent);
      expect(accent.onPrimary, core.onAccent);
    });

    test('should give the entitled green the label that reads on it', () {
      final accent = PremiumAccent.entitled(palette);

      expect(accent.primary, core.premiumInk);
      expect(accent.onPrimary, AppPalette.labelOnBright);
    });
  });
}
