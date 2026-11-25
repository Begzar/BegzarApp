import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flagCode on a config name', () {
    test('the two letters before the hyphen are the code', () {
      expect(
        const PremiumServerConfig(
          id: 1,
          name: 'FI-01 - ALL NEW',
          url: '',
        ).flagCode,
        'fi',
      );
      expect(
        const PremiumServerConfig(id: 1, name: 'DE-04 - RL', url: '').flagCode,
        'de',
      );
      expect(
        const PremiumServerConfig(id: 1, name: 'UK-01 - ALL', url: '').flagCode,
        'uk',
      );
    });

    test('a name without that prefix has no code', () {
      expect(
        const PremiumServerConfig(id: 1, name: 'Frankfurt 1', url: '').flagCode,
        isNull,
      );
    });
  });

  test('a server takes the first config\'s code', () {
    const server = PremiumServer(
      id: 22,
      name: 'Finland - Recommended',
      configs: [
        PremiumServerConfig(id: 32, name: 'FI-01 - ALL NEW', url: ''),
        PremiumServerConfig(id: 33, name: 'DE-01 - ALL NEW', url: ''),
      ],
    );

    expect(server.flagCode, 'fi');
  });
}
