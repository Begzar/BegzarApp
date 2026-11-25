import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/ads/presentation/ads_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = AppPalette.dark;
  const palette = AdsPalette(core);

  group('AdsPalette', () {
    test('should show the ad on the core overlay', () {
      expect(palette.overlay, core.overlay);
    });

    test('should draw the badge glyph in the warning ink', () {
      expect(palette.badgeGlyph, core.warningInk);
    });

    test('should run the rail in three stops of the warning', () {
      expect(palette.railRunning, hasLength(AdsPalette.railStops.length));
    });
  });
}
