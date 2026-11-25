import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/notifications/presentation/notifications_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = AppPalette.dark;
  const palette = NotificationsPalette(core);

  group('NotificationsPalette', () {
    test("should draw the gate's mark in the tunnel blue", () {
      expect(palette.accent, core.connected);
    });

    test('should set the title in the page neutral', () {
      expect(palette.textPrimary, core.veil);
    });
  });
}
