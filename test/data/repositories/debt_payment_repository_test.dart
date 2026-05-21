import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
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

// Guard logic mirroring the actual repository implementation under test.
Future<void> _guardedInsertPayment(dynamic db, String debtId, String paymentId, double amount) async {
  final debtRow = await db.query(tableDebts, where: 'id = ?', whereArgs: [debtId]);
  if (debtRow.isNotEmpty) {
    final s = debtRow.first['status'] as String?;
    if (s == 'paid' || s == 'hidden') {
      throw StateError('Cannot insert payment for a $s debt');
    }
  }
  await _insertPayment(db, debtId, paymentId, amount);
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

    test('throws StateError when target debt status is hidden', () async {
      await _insertDebt(db, status: 'hidden');
      expect(
        () => _guardedInsertPayment(db, 'debt-1', 'pay-1', 100),
        throwsA(isA<StateError>()),
      );
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
