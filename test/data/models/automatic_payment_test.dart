import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/automatic_payment.dart';

void main() {
  group('AutomaticPayment.status', () {
    test('toJson incluye status', () {
      final p = AutomaticPayment(
        id: 'auto-1',
        userId: 'user-1',
        paymentType: 'credit_card',
        paymentRef: 'card-1',
        amount: 1000,
        description: 'Pago tarjeta',
        nextRunDate: DateTime(2026, 7, 10),
        status: 'paused',
      );
      expect(p.toJson()['status'], 'paused');
    });

    test('fromJson default status=active si falta', () {
      final json = {
        'id': 'auto-1',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 1000.0,
        'description': 'Pago tarjeta',
        'next_run_date': DateTime(2026, 7, 10).toIso8601String(),
      };
      final p = AutomaticPayment.fromJson(json);
      expect(p.status, 'active');
    });

    test('fromJson respeta status=paused', () {
      final json = {
        'id': 'auto-1',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 1000.0,
        'description': 'Pago tarjeta',
        'next_run_date': DateTime(2026, 7, 10).toIso8601String(),
        'status': 'paused',
      };
      final p = AutomaticPayment.fromJson(json);
      expect(p.status, 'paused');
    });

    test('copyWith cambia solo status', () {
      final p = AutomaticPayment(
        id: 'auto-1',
        userId: 'user-1',
        paymentType: 'credit_card',
        paymentRef: 'card-1',
        amount: 1000,
        description: 'Pago tarjeta',
        nextRunDate: DateTime(2026, 7, 10),
      );
      final updated = p.copyWith(status: 'paused');
      expect(updated.status, 'paused');
      expect(updated.amount, 1000);
    });

    test('default status es active', () {
      final p = AutomaticPayment(
        id: 'auto-1',
        userId: 'user-1',
        paymentType: 'credit_card',
        paymentRef: 'card-1',
        amount: 1000,
        description: 'Pago tarjeta',
        nextRunDate: DateTime(2026, 7, 10),
      );
      expect(p.status, 'active');
    });
  });
}
