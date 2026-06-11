import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/mirrored_debt_payment.dart';

void main() {
  group('MirroredDebtPayment', () {
    test('constructs from JSON with correct fields', () {
      final json = {
        'id': 'mpay-1',
        'mirrored_debt_id': 'mirror-1',
        'amount': 250.0,
        'date': '2026-06-01T00:00:00.000Z',
        'created_at': '2026-06-01T10:00:00.000Z',
      };

      final payment = MirroredDebtPayment.fromJson(json);

      expect(payment.id, 'mpay-1');
      expect(payment.mirroredDebtId, 'mirror-1');
      expect(payment.amount, 250.0);
      expect(payment.date, isNotNull);
      expect(payment.createdAt, '2026-06-01T10:00:00.000Z');
    });

    test('has no note field', () {
      final json = {
        'id': 'mpay-2',
        'mirrored_debt_id': 'mirror-2',
        'amount': 100.0,
        'date': '2026-05-15T00:00:00.000Z',
      };

      final payment = MirroredDebtPayment.fromJson(json);
      final serialized = payment.toJson();

      // The model MUST NOT expose or serialize a note field
      expect(serialized.containsKey('note'), isFalse);
    });

    test('toJson round-trips core fields', () {
      final payment = MirroredDebtPayment(
        id: 'mpay-3',
        mirroredDebtId: 'mirror-3',
        amount: 75.5,
        date: DateTime(2026, 3, 10),
      );

      final json = payment.toJson();
      expect(json['id'], 'mpay-3');
      expect(json['mirrored_debt_id'], 'mirror-3');
      expect(json['amount'], 75.5);
      expect(json['date'], isNotNull);
    });
  });
}
