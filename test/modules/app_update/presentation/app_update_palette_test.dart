import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/app_update/presentation/app_update_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WCAG contrast ratio between two opaque colours.
double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

/// What text needs against what it is read on.
const _textContrast = 4.5;

void main() {
  const core = AppPalette.dark;
  const palette = AppUpdatePalette(core);

  group('AppUpdatePalette', () {
    test("should take the dialog's accent from the core palette", () {
      expect(palette.accent, core.accent);
    });

    test('should draw hairlines in the page neutral', () {
      expect(palette.divider, isSameColorAs(core.veil.withValues(alpha: 0.08)));
    });

    test('should mark a newer release in the warning', () {
      expect(palette.notice, core.warning);
    });

    // The shade that recesses the version card on a dark dialog turned it a
    // heavy grey on a light one, with its labels near 3:1.
    for (final theme in [AppPalette.dark, AppPalette.light]) {
      test('should keep the version card\'s labels readable in '
          '${theme.brightness.name}', () {
        final themed = AppUpdatePalette(theme);
        final well = Color.alphaBlend(themed.card, theme.dialog);

        expect(
          _contrast(themed.textMuted, well),
          greaterThanOrEqualTo(_textContrast),
        );
        expect(
          _contrast(themed.warn, well),
          greaterThanOrEqualTo(_textContrast),
        );
      });
    }
  });
}
