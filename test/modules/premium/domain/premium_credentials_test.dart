import 'package:begzar/modules/premium/domain/premium_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trims the username but never the password', () {
    final credentials = PremiumCredentials.parse(
      username: '  user  ',
      password: '  pass  ',
    );

    expect(credentials?.username, 'user');
    expect(
      credentials?.password,
      '  pass  ',
      reason: 'whitespace can be a deliberate part of a password',
    );
  });

  test('a username that is only whitespace does not parse', () {
    expect(PremiumCredentials.parse(username: '   ', password: 'pass'), isNull);
  });

  test('a blank password does not parse', () {
    expect(PremiumCredentials.parse(username: 'user', password: ''), isNull);
  });
}
