import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/email.dart';

void main() {
  group('isValidEmail', () {
    test('acepta correos comunes', () {
      expect(isValidEmail('juan@gmail.com'), isTrue);
      expect(isValidEmail('maria.lopez+cobros@empresa.com.co'), isTrue);
      expect(isValidEmail('  juan@gmail.com  '), isTrue);
    });

    test('rechaza formatos que no son correo', () {
      for (final email in [
        '',
        'not-an-email',
        'juan@gmail',
        'juan@.com',
        'juan@gmail.',
        '@gmail.com',
        'juan perez@gmail.com',
        'juan@@gmail.com',
        'juan@gmail..com',
      ]) {
        expect(isValidEmail(email), isFalse, reason: email);
      }
    });
  });
}
