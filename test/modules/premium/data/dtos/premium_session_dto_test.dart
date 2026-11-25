import 'package:begzar/modules/premium/data/dtos/premium_session_dto.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a round trip drops leftover password and config_source fields', () {
    final session = PremiumSessionDto.fromJson({
      'access_key': 'key',
      'username': 'user',
      'expire_date': '2099-01-01',
      'password': 'should-not-be-kept',
      'config_source': 'premium',
    });

    final rewritten = PremiumSessionDto.toJson(session);
    expect(rewritten.containsKey('password'), isFalse);
    expect(rewritten.containsKey('config_source'), isFalse);
    expect(session.account.username, 'user');
  });

  test(
    'an absent user_status round-trips as absent rather than as a label',
    () {
      final session = PremiumSessionDto.fromJson({
        'access_key': 'key',
        'username': 'user',
        'expire_date': '2099-01-01',
      });

      expect(session.account.statusLabel, isNull);
      expect(
        PremiumSessionDto.toJson(session).containsKey('user_status'),
        isFalse,
      );
    },
  );

  group('PremiumSessionDto for a never-paid account', () {
    test('should round-trip a session with no expiry', () {
      const session = PremiumSession(
        accessKey: 'key',
        account: PremiumAccount(username: 'user'),
      );

      final written = PremiumSessionDto.toJson(session);
      final read = PremiumSessionDto.fromJson(written);

      expect(written.containsKey('expire_date'), isFalse);
      expect(read.account.expireDate, isNull);
    });

    test('should read a stored record without expire_date', () {
      final session = PremiumSessionDto.fromJson({
        'access_key': 'key',
        'username': 'user',
      });

      expect(session.account.neverSubscribed, isTrue);
    });

    test('should round-trip email when present', () {
      const session = PremiumSession(
        accessKey: 'key',
        account: PremiumAccount(
          username: 'reader',
          email: 'reader@example.com',
        ),
      );

      final written = PremiumSessionDto.toJson(session);
      final read = PremiumSessionDto.fromJson(written);

      expect(written['email'], 'reader@example.com');
      expect(read.account.email, 'reader@example.com');
    });
  });
}
