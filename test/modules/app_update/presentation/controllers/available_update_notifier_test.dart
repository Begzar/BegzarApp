import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AvailableUpdateNotifier', () {
    test('should hold nothing until an update is published', () {
      final container = _container();

      expect(container.read(availableUpdateProvider), isNull);
    });

    test('should hold the published release and its page', () {
      final container = _container();

      container
          .read(availableUpdateProvider.notifier)
          .publish(version: '7.0.0', url: 'https://example.test/update');

      final update = container.read(availableUpdateProvider);
      expect(update?.version, '7.0.0');
      expect(update?.url, 'https://example.test/update');
    });
  });
}
