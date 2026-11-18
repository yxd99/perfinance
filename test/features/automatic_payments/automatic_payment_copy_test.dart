import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_copy.dart';

AutomaticPayment _p({String status = 'active', String frequency = 'mensual'}) => AutomaticPayment(
  id: 'a1',
  userId: 'u1',
  paymentType: 'credit_card',
  paymentRef: 'c1',
  amount: 45000,
  description: 'Netflix',
  nextRunDate: DateTime(2026, 12, 15),
  paymentDayOfMonth: 15,
  frequency: frequency,
  status: status,
);

void main() {
  group('frequencyLabel', () {
    test('traduce cada frecuencia guardada', () {
      expect(frequencyLabel('mensual'), 'Mensual');
      expect(frequencyLabel('trimestral'), 'Trimestral');
      expect(frequencyLabel('semestral'), 'Semestral');
      expect(frequencyLabel('anual'), 'Anual');
    });
  });

  group('automaticPaymentStatusLine', () {
    test('activo: día, frecuencia y cuenta', () {
      expect(automaticPaymentStatusLine(_p(), accountName: 'Visa'), 'Día 15 · Mensual · Visa');
      expect(isAutomaticPaymentPaused(_p()), isFalse);
    });

    test('en pausa: empieza con "En pausa"', () {
      final p = _p(status: 'paused', frequency: 'anual');
      expect(automaticPaymentStatusLine(p, accountName: 'Visa'), 'En pausa · Día 15 · Anual · Visa');
      expect(isAutomaticPaymentPaused(p), isTrue);
    });
  });
}
