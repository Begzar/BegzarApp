import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:flutter_test/flutter_test.dart';

PremiumServerConfig _config(String url) =>
    PremiumServerConfig(id: 1, name: 'Config', url: url);

void main() {
  group('PremiumServerConfig.hasValidUrl', () {
    test('lists a hysteria2 config, which a manual pick can dial', () {
      expect(_config('hysteria2://host:443').hasValidUrl, isTrue);
    });

    test('hides a hysteria v1 config, which the engine cannot dial', () {
      expect(_config('hysteria://host:443').hasValidUrl, isFalse);
    });
  });
}
