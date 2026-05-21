import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';

void main() {
  final baseJson = {
    'id': 'debt-1',
    'user_id': 'user-1',
    'name': 'Deuda test',
    'total_amount': 100000.0,
    'number_of_installments': 12,
    'due_date': '2026-12-31T00:00:00.000',
    'sync_status': 'synced',
    'updated_at': null,
    'created_at': null,
  };

  group('Debt.fromJson — status', () {
    test('maps status:paid to DebtStatus.paid', () {
      final json = {...baseJson, 'status': 'paid'};
      expect(Debt.fromJson(json).status, DebtStatus.paid);
    });

    test('maps status:hidden to DebtStatus.hidden', () {
      final json = {...baseJson, 'status': 'hidden'};
      expect(Debt.fromJson(json).status, DebtStatus.hidden);
    });

    test('defaults to DebtStatus.active when status key absent', () {
      expect(Debt.fromJson(baseJson).status, DebtStatus.active);
    });

    test('defaults to DebtStatus.active when status value is unknown', () {
      final json = {...baseJson, 'status': 'something_weird'};
      expect(Debt.fromJson(json).status, DebtStatus.active);
    });
  });

  group('Debt.toJson — status', () {
    test('serializes DebtStatus.active as active', () {
      final d = Debt(
        id: 'debt-1',
        userId: 'user-1',
        name: 'Test',
        totalAmount: 100000,
        numberOfInstallments: 12,
        dueDate: DateTime(2026, 12, 31),
        status: DebtStatus.active,
      );
      expect(d.toJson()['status'], 'active');
    });

    test('serializes DebtStatus.paid as paid', () {
      final d = Debt(
        id: 'debt-1',
        userId: 'user-1',
        name: 'Test',
        totalAmount: 100000,
        numberOfInstallments: 12,
        dueDate: DateTime(2026, 12, 31),
        status: DebtStatus.paid,
      );
      expect(d.toJson()['status'], 'paid');
    });

    test('serializes DebtStatus.hidden as hidden', () {
      final d = Debt(
        id: 'debt-1',
        userId: 'user-1',
        name: 'Test',
        totalAmount: 100000,
        numberOfInstallments: 12,
        dueDate: DateTime(2026, 12, 31),
        status: DebtStatus.hidden,
      );
      expect(d.toJson()['status'], 'hidden');
    });
  });

  group('Debt constructor default', () {
    test('defaults status to DebtStatus.active', () {
      final d = Debt(
        id: 'debt-1',
        userId: 'user-1',
        name: 'Test',
        totalAmount: 100000,
        numberOfInstallments: 12,
        dueDate: DateTime(2026, 12, 31),
      );
      expect(d.status, DebtStatus.active);
    });
  });
}
