import 'package:begzar/modules/app_update/domain/version_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('orders dotted versions', () {
      expect(compareVersions('6.8.0', '6.8.0'), 0);
      expect(compareVersions('6.7.9', '6.8.0'), lessThan(0));
      expect(compareVersions('6.9.0', '6.8.0'), greaterThan(0));
      expect(compareVersions('6.8', '6.8.0'), 0);
      expect(compareVersions('6.8.0.1', '6.8.0'), greaterThan(0));
    });

    test('a malformed segment reads as zero rather than throwing', () {
      expect(compareVersions('6.8.beta', '6.8.0'), 0);
      expect(compareVersions('', '0.0.0'), 0);
      expect(compareVersions('6.8.1', '6.8.beta'), greaterThan(0));
    });
  });
}
