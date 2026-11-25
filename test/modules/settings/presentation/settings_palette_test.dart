import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = AppPalette.dark;
  const palette = SettingsPalette(core);

  group('SettingsPalette', () {
    test('should take its page from the core palette', () {
      expect(palette.pageInk, core.page);
    });

    // On the near-white light card a 7% wash of the accent barely showed;
    // dark keeps it, where the lighter accent already reads at that strength.
    test('should tint a chosen row harder on a light page', () {
      expect(
        const SettingsPalette(AppPalette.light).selectedRow,
        isSameColorAs(AppPalette.light.accent.withValues(alpha: 0.12)),
      );
      expect(
        const SettingsPalette(AppPalette.dark).selectedRow,
        isSameColorAs(AppPalette.dark.accent.withValues(alpha: 0.07)),
      );
    });

    // An entry's icon sits in the row's raised tile, which has to stand off
    // the menu as it stands off a settings card, in both themes. The dialog's
    // surface was the tile's own colour in dark, and the tiles vanished.
    test('should open its menus on a card the icon tiles stand off', () {
      for (final core in [AppPalette.dark, AppPalette.light]) {
        final palette = SettingsPalette(core);
        expect(palette.menuSurface, core.surface);
        expect(palette.menuSurface, isNot(palette.cardRaised));
      }
    });

    test('should keep the switch track at its tint of the accent', () {
      expect(
        palette.switchTrackOn,
        isSameColorAs(core.accent.withValues(alpha: 0.45)),
      );
    });
  });

  group('RoutingActionColor', () {
    test('should colour a blocking rule in the failure ink', () {
      expect(RoutingAction.block.colorIn(palette), core.failedInk);
    });

    test('should colour a proxied rule in the tunnel ink', () {
      expect(RoutingAction.proxy.colorIn(palette), core.connectedInk);
    });
  });
}
