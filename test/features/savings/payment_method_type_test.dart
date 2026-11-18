import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/savings/payment_method_type.dart';

void main() {
  group('paymentMethodTypeLabel', () {
    test('efectivo, tanto el valor del formulario como el heredado', () {
      expect(paymentMethodTypeLabel('efectivo'), 'Efectivo');
      expect(paymentMethodTypeLabel('cash'), 'Efectivo');
    });

    test('débito, tanto el valor del formulario como el heredado', () {
      expect(paymentMethodTypeLabel('debito'), 'Débito');
      expect(paymentMethodTypeLabel('debit'), 'Débito');
    });

    test('otro y cualquier valor desconocido nunca muestran el valor crudo', () {
      expect(paymentMethodTypeLabel('other'), 'Otro');
      expect(paymentMethodTypeLabel(''), 'Otro');
      expect(paymentMethodTypeLabel('nequi_raw'), 'Otro');
    });

    test('ignora mayúsculas y espacios', () {
      expect(paymentMethodTypeLabel(' CASH '), 'Efectivo');
    });
  });

  group('paymentMethodFormType', () {
    test('normaliza los valores heredados a los del formulario', () {
      expect(paymentMethodFormType('cash'), 'efectivo');
      expect(paymentMethodFormType('debit'), 'debito');
      expect(paymentMethodFormType('efectivo'), 'efectivo');
      expect(paymentMethodFormType('raro'), 'other');
    });
  });
}
