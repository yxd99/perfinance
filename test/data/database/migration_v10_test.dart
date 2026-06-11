import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  group('v9 → v10 migration', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(fromVersion: 9);
    });

    tearDown(() async {
      await db.close();
    });

    test('v9 to v10 upgrade creates mirrored_debts and mirrored_debt_payments tables', () async {
      final mirroredDebtsInfo =
          await db.rawQuery('PRAGMA table_info($tableMirroredDebts)');
      final mirroredDebtPaymentsInfo =
          await db.rawQuery('PRAGMA table_info($tableMirroredDebtPayments)');

      expect(mirroredDebtsInfo, isNotEmpty, reason: 'mirrored_debts table should exist');
      expect(mirroredDebtPaymentsInfo, isNotEmpty, reason: 'mirrored_debt_payments table should exist');

      final debtsColumns = (mirroredDebtsInfo as List)
          .map((r) => r['name'] as String)
          .toSet();
      expect(debtsColumns, containsAll([
        'id',
        'receivable_id',
        'debtor_user_id',
        'creditor_user_id',
        'creditor_email',
        'debtor_name',
        'total_amount',
        'description',
        'due_date',
        'status',
        'revoked_at',
        'sync_status',
        'updated_at',
        'created_at',
      ]));

      final paymentsColumns = (mirroredDebtPaymentsInfo as List)
          .map((r) => r['name'] as String)
          .toSet();
      expect(paymentsColumns, containsAll([
        'id',
        'mirrored_debt_id',
        'source_payment_id',
        'amount',
        'date',
        'sync_status',
        'updated_at',
        'created_at',
      ]));
    });

    test('v10 upgrade creates idx_mirrored_debts_debtor and idx_mirrored_pay_debt', () async {
      final debtorIndex = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_mirrored_debts_debtor'",
      );
      final payIndex = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_mirrored_pay_debt'",
      );
      expect(debtorIndex, isNotEmpty, reason: 'idx_mirrored_debts_debtor should exist');
      expect(payIndex, isNotEmpty, reason: 'idx_mirrored_pay_debt should exist');
    });

    test('deleting a mirrored_debt cascades to its mirrored_debt_payments (FK pragma on)', () async {
      final now = DateTime.now().toIso8601String();
      await db.execute('PRAGMA foreign_keys = ON');

      await db.insert(tableMirroredDebts, {
        'id': 'mirror-1',
        'receivable_id': 'recv-1',
        'debtor_user_id': 'debtor-1',
        'creditor_user_id': 'creditor-1',
        'creditor_email': 'creditor@example.com',
        'total_amount': 500.0,
        'status': 'active',
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      await db.insert(tableMirroredDebtPayments, {
        'id': 'mpay-1',
        'mirrored_debt_id': 'mirror-1',
        'source_payment_id': 'spay-1',
        'amount': 100.0,
        'date': now,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      final before = await db.query(
        tableMirroredDebtPayments,
        where: 'mirrored_debt_id = ?',
        whereArgs: ['mirror-1'],
      );
      expect(before, hasLength(1));

      await db.delete(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-1']);

      final after = await db.query(
        tableMirroredDebtPayments,
        where: 'mirrored_debt_id = ?',
        whereArgs: ['mirror-1'],
      );
      expect(after, isEmpty, reason: 'payments should cascade-delete with parent mirrored_debt');
    });
  });

  group('fresh install (_onCreate) has mirrored tables', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(); // fresh install path
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh install (_onCreate) has mirrored tables with FK on mirrored_debt_payments', () async {
      final mirroredDebtsInfo =
          await db.rawQuery('PRAGMA table_info($tableMirroredDebts)');
      final mirroredDebtPaymentsInfo =
          await db.rawQuery('PRAGMA table_info($tableMirroredDebtPayments)');

      expect(mirroredDebtsInfo, isNotEmpty, reason: 'mirrored_debts must exist on fresh install');
      expect(mirroredDebtPaymentsInfo, isNotEmpty, reason: 'mirrored_debt_payments must exist on fresh install');

      // Verify FK cascade works on fresh install too
      final now = DateTime.now().toIso8601String();
      await db.execute('PRAGMA foreign_keys = ON');

      await db.insert(tableMirroredDebts, {
        'id': 'mirror-f1',
        'receivable_id': 'recv-f1',
        'debtor_user_id': 'debtor-f1',
        'creditor_user_id': 'creditor-f1',
        'creditor_email': 'creditor@example.com',
        'total_amount': 200.0,
        'status': 'active',
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      await db.insert(tableMirroredDebtPayments, {
        'id': 'mpay-f1',
        'mirrored_debt_id': 'mirror-f1',
        'source_payment_id': 'spay-f1',
        'amount': 50.0,
        'date': now,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      await db.delete(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-f1']);

      final after = await db.query(
        tableMirroredDebtPayments,
        where: 'mirrored_debt_id = ?',
        whereArgs: ['mirror-f1'],
      );
      expect(after, isEmpty, reason: 'FK cascade must work on fresh install path');
    });
  });
}
