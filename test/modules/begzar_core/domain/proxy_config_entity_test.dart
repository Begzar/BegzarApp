import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('building configs out of a subscription', () {
    test('numbers them from one, in the order the server sent them', () {
      final configs = proxyConfigsFromSubscription(const [
        'first://a',
        'second://b',
        'third://c',
      ]);

      expect(configs.map((c) => c.name), ['Server 1', 'Server 2', 'Server 3']);
      expect(configs.map((c) => c.url), [
        'first://a',
        'second://b',
        'third://c',
      ], reason: 'the order is the only ranking the server gives');
    });

    test('an empty subscription builds nothing', () {
      expect(proxyConfigsFromSubscription(const []), isEmpty);
    });

    test('every config gets a name, so validation cannot reject one', () {
      final configs = proxyConfigsFromSubscription(const ['only://one']);

      expect(configs.single.name, isNotEmpty);
    });
  });
}
