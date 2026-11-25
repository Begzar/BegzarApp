import 'package:begzar/modules/premium/domain/play_account_tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('playAccountTag', () {
    test('should tag an account with 64 hex characters', () {
      final tag = playAccountTag('reader@example.com');

      expect(tag, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('should tag the same username the same way', () {
      expect(
        playAccountTag('reader@example.com'),
        playAccountTag('reader@example.com'),
      );
      expect(
        playAccountTag('reader@example.com'),
        isNot(playAccountTag('other@example.com')),
      );
    });
  });
}
