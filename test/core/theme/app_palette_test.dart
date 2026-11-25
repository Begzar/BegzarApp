import 'package:begzar/core/domain/surface_mood.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WCAG contrast ratio between two opaque colours.
double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

/// What text needs against what it is read on.
const _textContrast = 4.5;

void main() {
  group('AppPalette', () {
    test('should keep light values from the token sheet', () {
      const palette = AppPalette.light;

      expect(palette.brightness, Brightness.light);
      expect(palette.page, const Color(0xFFE2E7EE));
      expect(palette.surface, const Color(0xFFF4F6F9));
      expect(palette.surfaceRaised, const Color(0xFFE3E8EF));
      expect(palette.line, const Color(0x240E1420));
      expect(palette.lineStrong, const Color(0x380E1420));
      expect(palette.text, const Color(0xFF0E1420));
      expect(palette.accent, const Color(0xFF1563C7));
      expect(palette.premiumInk, const Color(0xFF0C7058));
      expect(palette.warningInk, const Color(0xFF905400));
    });

    // Three steps rather than two near-whites: the page, a card resting on
    // it, and pure white kept for what floats above both.
    test('should lighten from the page to a card to what floats in light', () {
      const palette = AppPalette.light;
      final page = palette.page.computeLuminance();
      final card = palette.surface.computeLuminance();

      expect(card, greaterThan(page));
      expect(palette.dialog.computeLuminance(), greaterThan(card));
      expect(palette.sheet.computeLuminance(), greaterThan(card));
      expect(palette.overlay, palette.page);
    });

    for (final palette in [AppPalette.dark, AppPalette.light]) {
      test('should keep every text role at 4.5:1 on cards and the page in '
          '${palette.brightness.name}', () {
        final roles = {
          'text': palette.text,
          'textSecondary': palette.textSecondary,
          'muted': palette.muted,
          'accent': palette.accent,
          'premiumInk': palette.premiumInk,
          'failedInk': palette.failedInk,
          'warningInk': palette.warningInk,
        };
        for (final ground in [palette.surface, palette.page]) {
          for (final role in roles.entries) {
            expect(
              _contrast(role.value, ground),
              greaterThanOrEqualTo(_textContrast),
              reason: '${role.key} on $ground',
            );
          }
        }
      });

      test('should keep snack ink readable in ${palette.brightness.name}', () {
        expect(
          _contrast(palette.onSnack, palette.snack),
          greaterThanOrEqualTo(_textContrast),
        );
      });
    }

    test("should keep today's dark values", () {
      const palette = AppPalette.dark;

      expect(palette.brightness, Brightness.dark);
      expect(palette.page, const Color(0xFF0A0D12));
      expect(palette.text, const Color(0xFFEDF0F4));
      expect(palette.accent, const Color(0xFF4DA8FF));
      expect(palette.premiumInk, const Color(0xFF5ED6B8));
      expect(palette.warning, const Color(0xFFF5B83D));
      expect(palette.pageIdle.first, const Color(0xFF0D131C));
    });

    test('should paint the page gradient for a mood top to bottom', () {
      final gradient = AppPalette.dark.pageGradient(SurfaceMood.active);

      expect(gradient.colors, AppPalette.dark.pageActive);
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
    });

    test('should return each end at t 0 and 1', () {
      const other = AppPalette.dark;
      final start = AppPalette.dark.lerp(other, 0);
      final end = AppPalette.dark.lerp(other, 1);

      expect(start.text, AppPalette.dark.text);
      expect(end.pageIdle, AppPalette.dark.pageIdle);
    });

    testWidgets(
      'should fall back to the dark palette when the theme has none',
      (tester) async {
        late AppPalette read;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                read = context.palette;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(read, same(AppPalette.dark));
      },
    );
  });
}
