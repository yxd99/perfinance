import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

Future<void> _insertDebt(dynamic db, {
  String id = 'debt-1',
  double totalAmount = 1000,
  String status = 'active',
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableDebts, {
    'id': id,
    'user_id': 'user-1',
    'name': 'Test',
    'total_amount': totalAmount,
    'number_of_installments': 12,
    'due_date': '2026-12-31',
    'status': status,
    columnSyncStatus: 'synced',
    columnUpdatedAt: now,
    'created_at': now,
  });
}

Future<void> _insertPayment(dynamic db, String debtId, String paymentId, double amount) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableDebtPayments, {
    'id': paymentId,
    'debt_id': debtId,
    'amount': amount,
    'date': '2026-05-01',
    columnSyncStatus: 'synced',
    columnUpdatedAt: now,
    'created_at': now,
  });
}

Future<void> _guardedInsertPayment(dynamic db, String debtId, String paymentId, double amount) {
  return DebtPaymentRepository(null, dbOverride: db).insert(
    DebtPayment(id: paymentId, debtId: debtId, amount: amount, date: DateTime(2026, 5, 1)),
  );
}

void main() {
  sqfliteFfiInit();

  late dynamic db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('DebtPaymentRepository.insert guard', () {
    test('throws StateError when target debt status is paid', () async {
      await _insertDebt(db, status: 'paid');
      expect(
        () => _guardedInsertPayment(db, 'debt-1', 'pay-1', 100),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds when target debt status is hidden', () async {
      await _insertDebt(db, status: 'hidden');
      await _guardedInsertPayment(db, 'debt-1', 'pay-1', 100);

      final rows = await db.query(tableDebtPayments) as List;
      expect(rows.single['amount'], 100.0);
      expect(rows.single[columnSyncStatus], 'pending_insert');
      final debt = (await db.query(tableDebts) as List).single;
      expect(debt['status'], 'hidden');
    });

    test('succeeds when target debt status is active', () async {
      await _insertDebt(db, status: 'active');
      await expectLater(
        _guardedInsertPayment(db, 'debt-1', 'pay-1', 100),
        completes,
      );
    });
  });

  group('delete payment — allowed regardless of debt status', () {
    test('delete succeeds even when target debt status is paid', () async {
      await _insertDebt(db, status: 'paid');
      await _insertPayment(db, 'debt-1', 'pay-1', 100);
      await db.delete(tableDebtPayments, where: 'id = ?', whereArgs: ['pay-1']);
      final rows = await db.query(tableDebtPayments, where: 'id = ?', whereArgs: ['pay-1']);
      expect(rows, isEmpty);
    });

    test('delete succeeds even when target debt status is hidden', () async {
      await _insertDebt(db, status: 'hidden');
      await _insertPayment(db, 'debt-1', 'pay-1', 100);
      await db.delete(tableDebtPayments, where: 'id = ?', whereArgs: ['pay-1']);
      final rows = await db.query(tableDebtPayments, where: 'id = ?', whereArgs: ['pay-1']);
      expect(rows, isEmpty);
    });
  });
}
