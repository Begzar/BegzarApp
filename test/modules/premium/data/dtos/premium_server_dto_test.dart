import 'package:begzar/modules/premium/data/dtos/premium_server_dto.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scheme prefixes only — no host, no credentials, nothing dialable. The
/// prefix is the whole point: it is what the dialable filter reads.
const _supportedScheme = 'vless://';
const _unsupportedScheme = 'wireguard://';

BackendPremiumConfig _config({
  int id = 1,
  String? name = 'Frankfurt 1',
  String url = '${_supportedScheme}example',
}) => BackendPremiumConfig(id: id, name: name, url: url);

BackendPremiumServer _server({
  String? icon,
  List<BackendPremiumConfig>? configs,
}) => BackendPremiumServer(
  id: 10,
  name: 'Germany',
  icon: icon,
  configs: configs ?? [_config()],
);

void main() {
  group('reading the servers the engine listed', () {
    test('reads ids, names, icons and configs', () {
      final servers = PremiumServerDto.listFromBackend([
        _server(icon: 'https://cdn.example/de.png'),
      ]);

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.id, 10);
      expect(server.name, 'Germany');
      expect(server.icon, 'https://cdn.example/de.png');
      expect(server.configs.single.name, 'Frankfurt 1');
    });

    test('drops a config whose scheme the tunnel cannot dial', () {
      final servers = PremiumServerDto.listFromBackend([
        _server(
          configs: [
            _config(id: 1),
            _config(id: 2, url: '${_unsupportedScheme}example'),
          ],
        ),
      ]);

      expect(servers.single.configs.map((config) => config.id), [1]);
    });

    test('drops a server left with no dialable config', () {
      final servers = PremiumServerDto.listFromBackend([
        _server(configs: [_config(url: '${_unsupportedScheme}example')]),
      ]);

      expect(servers, isEmpty);
    });

    test('names what the backend left unnamed', () {
      final servers = PremiumServerDto.listFromBackend([
        const BackendPremiumServer(
          id: 0,
          configs: [BackendPremiumConfig(id: 0, url: '${_supportedScheme}x')],
        ),
      ]);

      expect(servers.single.name, 'Server');
      expect(servers.single.configs.single.name, 'Server');
    });
  });
}
