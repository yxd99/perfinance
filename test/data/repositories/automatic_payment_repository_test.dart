import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/automatic_payment.dart';

void main() {
  group('AutomaticPayment.fromMap', () {
    test('con payment_day_of_month y frequency presentes', () {
      final map = {
        'id': 'test-id',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 50000.0,
        'description': 'Netflix',
        'next_run_date': '2024-03-15T00:00:00.000',
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
        'payment_day_of_month': 15,
        'frequency': 'trimestral',
      };

      final payment = AutomaticPayment.fromMap(map);

      expect(payment.paymentDayOfMonth, 15);
      expect(payment.frequency, 'trimestral');
    });

    test('con payment_day_of_month y frequency null — fallback desde next_run_date', () {
      final map = {
        'id': 'test-id-2',
        'user_id': 'user-1',
        'payment_type': 'payment_method',
        'payment_ref': 'method-1',
        'amount': 30000.0,
        'description': 'Gym',
        'next_run_date': '2024-03-28T00:00:00.000',
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
        'payment_day_of_month': null,
        'frequency': null,
      };

      final payment = AutomaticPayment.fromMap(map);

      expect(payment.paymentDayOfMonth, 28);
      expect(payment.frequency, 'mensual');
    });
  });
}
