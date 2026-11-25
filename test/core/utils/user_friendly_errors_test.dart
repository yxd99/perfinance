import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';

void main() {
  group('expenseExportEmailMessage', () {
    test('muestra el mensaje del tope mensual sin el código HTTP', () {
      final message = UserFriendlyErrors.expenseExportEmailMessage(
        Exception(
          'Llegaste al límite de 10 correos de este mes. Podrás enviar más desde el 1 de diciembre. (429)',
        ),
      );
      expect(
        message,
        'Llegaste al límite de 10 correos de este mes. Podrás enviar más desde el 1 de diciembre.',
      );
    });

    test('sin error devuelve el mensaje genérico', () {
      expect(
        UserFriendlyErrors.expenseExportEmailMessage(null),
        UserFriendlyErrors.expenseExportEmailFailed,
      );
    });
  });
}
