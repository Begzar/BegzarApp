import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WarpMode', () {
    // The stored name is the engine's: the core's launch payload reads it,
    // so a name that drifted would launch an engine that refuses the mode.
    test('names each mode the way the engine does', () {
      expect(
        {for (final mode in WarpMode.values) mode.engineName},
        {'masque', 'warp', 'gool', 'masque-psiphon', 'psiphon'},
      );
    });

    test('reads every stored name back', () {
      for (final mode in WarpMode.values) {
        expect(WarpMode.fromStored(mode.engineName), mode);
      }
    });

    test('nothing stored, or something unknown, is MASQUE', () {
      expect(WarpMode.fromStored(null), WarpMode.masque);
      expect(WarpMode.fromStored('teleport'), WarpMode.masque);
    });

    test('records its value without a dash', () {
      expect(WarpMode.masquePsiphon.analyticsValue, 'masque_psiphon');
      expect(WarpMode.gool.analyticsValue, 'gool');
    });
  });
}
