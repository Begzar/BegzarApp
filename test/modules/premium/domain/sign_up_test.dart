import 'package:begzar/modules/premium/domain/sign_up.dart';
import 'package:flutter_test/flutter_test.dart';

const _password = 'correct horse';

SignUpFieldError? _problemWith({
  String email = 'reader@example.com',
  String password = _password,
  String? confirmation,
}) => SignUpDetails.parse(
  email: email,
  password: password,
  confirmation: confirmation ?? password,
).getLeft().toNullable();

SignUpDetails _details({
  String email = 'reader@example.com',
  String password = _password,
}) => SignUpDetails.parse(
  email: email,
  password: password,
  confirmation: password,
).getOrElse((problem) => fail('$problem'));

void main() {
  group('SignUpDetails.parse', () {
    test('should trim the email', () {
      expect(
        _details(email: '  reader@example.com\n').email,
        'reader@example.com',
      );
    });

    test('should reject an email without a domain', () {
      expect(_problemWith(email: 'reader@'), SignUpFieldError.emailInvalid);
    });

    test('should reject a seven-character password', () {
      expect(
        _problemWith(password: 'x' * 7),
        SignUpFieldError.passwordTooShort,
      );
    });

    test('should accept an eight-character password', () {
      expect(
        _problemWith(password: 'x' * SignUpDetails.minimumPasswordLength),
        isNull,
      );
    });

    test('should keep spaces inside and around the password', () {
      expect(_details(password: ' pass word ').password, ' pass word ');
    });

    test('should reject a confirmation that differs', () {
      expect(
        _problemWith(confirmation: '$_password!'),
        SignUpFieldError.passwordMismatch,
      );
    });

    test('should report the email before the password', () {
      expect(
        _problemWith(email: 'nobody', password: 'short'),
        SignUpFieldError.emailInvalid,
      );
    });
  });

  group('ConfirmationCode.normalize', () {
    test('should accept a code pasted with a space', () {
      expect(ConfirmationCode.normalize('123 456'), '123456');
    });

    // A Persian keyboard types these, and a Persian mail client shows them.
    test('should accept Persian digits', () {
      expect(ConfirmationCode.normalize('۱۲۳۴۵۶'), '123456');
    });

    test('should accept Arabic-Indic digits', () {
      expect(ConfirmationCode.normalize('١٢٣٤٥٦'), '123456');
    });

    // Copying out of right-to-left text brings direction marks and joiners
    // along with the digits.
    test('should drop direction marks copied with the code', () {
      expect(ConfirmationCode.normalize('‏123‌456‎'), '123456');
    });

    test('should reject five digits', () {
      expect(ConfirmationCode.normalize('12345'), isNull);
    });

    test('should reject letters', () {
      expect(ConfirmationCode.normalize('12a456'), isNull);
    });
  });
}
