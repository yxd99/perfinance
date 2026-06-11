import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';

void main() {
  group('Debt.mirrored factory', () {
    test('Debt.mirrored sets isMirrored true, creditorEmail and mirroredDebtId', () {
      final d = Debt.mirrored(
        mirroredDebtId: 'mirror-1',
        userId: 'debtor-1',
        creditorEmail: 'creditor@example.com',
        name: 'Test Debt',
        totalAmount: 500.0,
        dueDate: DateTime(2026, 12, 31),
        status: 'active',
      );

      expect(d.isMirrored, isTrue);
      expect(d.creditorEmail, 'creditor@example.com');
      expect(d.mirroredDebtId, 'mirror-1');
    });

    test('Debt.mirrored with status revoked exposes isRevoked true', () {
      final d = Debt.mirrored(
        mirroredDebtId: 'mirror-2',
        userId: 'debtor-1',
        creditorEmail: 'creditor@example.com',
        name: 'Revoked Debt',
        totalAmount: 300.0,
        dueDate: DateTime(2026, 12, 31),
        status: 'revoked',
      );

      expect(d.isRevoked, isTrue);
    });

    test('Debt.mirrored with status active exposes isRevoked false', () {
      final d = Debt.mirrored(
        mirroredDebtId: 'mirror-3',
        userId: 'debtor-1',
        creditorEmail: 'creditor@example.com',
        name: 'Active Debt',
        totalAmount: 200.0,
        dueDate: DateTime(2026, 12, 31),
        status: 'active',
      );

      expect(d.isRevoked, isFalse);
    });
  });

  group('Normal Debt defaults', () {
    test('normal Debt has isMirrored false and null creditorEmail', () {
      final d = Debt(
        id: 'debt-1',
        userId: 'user-1',
        name: 'Normal Debt',
        totalAmount: 1000.0,
        numberOfInstallments: 12,
        dueDate: DateTime(2026, 12, 31),
      );

      expect(d.isMirrored, isFalse);
      expect(d.creditorEmail, isNull);
      expect(d.mirroredDebtId, isNull);
    });
  });

  group('Debt.toJson does not include mirror fields', () {
    test('Debt.toJson does NOT include isMirrored/creditorEmail/mirroredDebtId', () {
      final d = Debt.mirrored(
        mirroredDebtId: 'mirror-4',
        userId: 'debtor-1',
        creditorEmail: 'creditor@example.com',
        name: 'Mirror Debt',
        totalAmount: 400.0,
        dueDate: DateTime(2026, 12, 31),
        status: 'active',
      );

      final json = d.toJson();
      expect(json.containsKey('isMirrored'), isFalse);
      expect(json.containsKey('is_mirrored'), isFalse);
      expect(json.containsKey('creditorEmail'), isFalse);
      expect(json.containsKey('creditor_email'), isFalse);
      expect(json.containsKey('mirroredDebtId'), isFalse);
      expect(json.containsKey('mirrored_debt_id'), isFalse);
    });
  });
}
