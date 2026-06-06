import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable_payment.dart';

void main() {
  group('ReceivablePayment toJson/fromJson round-trip', () {
    test('round-trips a fully populated payment', () {
      final payment = ReceivablePayment(
        id: 'pay-1',
        receivableId: 'recv-1',
        amount: 250.0,
        date: DateTime(2026, 5, 15),
        note: 'First installment',
        syncStatus: 'synced',
        updatedAt: '2026-05-15T00:00:00.000',
        createdAt: '2026-05-15T00:00:00.000',
      );

      final json = payment.toJson();
      final restored = ReceivablePayment.fromJson(json);

      expect(restored.id, payment.id);
      expect(restored.receivableId, payment.receivableId);
      expect(restored.amount, payment.amount);
      expect(restored.date, payment.date);
      expect(restored.note, payment.note);
      expect(restored.syncStatus, payment.syncStatus);
      expect(restored.updatedAt, payment.updatedAt);
      expect(restored.createdAt, payment.createdAt);
    });

    test('round-trips with null note', () {
      final payment = ReceivablePayment(
        id: 'pay-2',
        receivableId: 'recv-1',
        amount: 100.0,
        date: DateTime(2026, 6, 1),
        note: null,
      );

      final restored = ReceivablePayment.fromJson(payment.toJson());
      expect(restored.note, isNull);
    });

    test('toJson includes receivable_id, amount, date keys', () {
      final payment = ReceivablePayment(
        id: 'pay-3',
        receivableId: 'recv-2',
        amount: 500.0,
        date: DateTime(2026, 7, 10),
      );

      final json = payment.toJson();
      expect(json, containsPair('receivable_id', 'recv-2'));
      expect(json, containsPair('amount', 500.0));
      expect(json.containsKey('date'), isTrue);
    });

    test('default syncStatus is synced', () {
      final p = ReceivablePayment(
        id: 'p',
        receivableId: 'r',
        amount: 1.0,
        date: DateTime.now(),
      );
      expect(p.syncStatus, 'synced');
    });

    test('fromJson defaults syncStatus to synced when absent', () {
      final json = {
        'id': 'pay-4',
        'receivable_id': 'recv-1',
        'amount': 50.0,
        'date': '2026-08-01T00:00:00.000',
      };
      final payment = ReceivablePayment.fromJson(json);
      expect(payment.syncStatus, 'synced');
    });
  });
}
