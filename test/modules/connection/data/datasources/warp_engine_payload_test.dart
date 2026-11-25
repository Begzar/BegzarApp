import 'dart:convert';

import 'package:begzar/modules/connection/data/datasources/warp_engine_payload.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('warpEnginePayload', () {
    // The engine refuses a field it does not know, so the payload carries
    // exactly these two and nothing else.
    test('carries the mode and the resolver, and nothing more', () {
      final payload = jsonDecode(
        warpEnginePayload(WarpMode.masquePsiphon, dnsServer: '9.9.9.9'),
      );
      expect(payload, {'mode': 'masque-psiphon', 'dns': '9.9.9.9'});
    });

    test('leaves the resolver to the engine when there is none', () {
      final payload = jsonDecode(
        warpEnginePayload(WarpMode.warp, dnsServer: ''),
      );
      expect(payload, {'mode': 'warp'});
    });
  });
}
