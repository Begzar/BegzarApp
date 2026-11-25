import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:flutter_test/flutter_test.dart';

ProxyConfigEntity _config(String url) =>
    ProxyConfigEntity(url: url, name: 'Config');

void main() {
  group('ProxyConfigValidator.isDialable', () {
    for (final scheme in [
      'vless',
      'vmess',
      'ss',
      'trojan',
      'hysteria2',
      'hy2',
    ]) {
      test('accepts a $scheme config the engine dials', () {
        expect(
          ProxyConfigValidator.isDialable(_config('$scheme://host:443')),
          isTrue,
        );
      });
    }

    test('rejects a hysteria v1 config the engine cannot dial', () {
      expect(
        ProxyConfigValidator.isDialable(_config('hysteria://host:443')),
        isFalse,
      );
    });

    test('rejects a config with no name', () {
      expect(
        ProxyConfigValidator.isDialable(
          const ProxyConfigEntity(url: 'vless://host:443', name: ''),
        ),
        isFalse,
      );
    });
  });
}
