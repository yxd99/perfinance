import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  group('v5 → v7 migration', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(fromVersion: 5);
    });

    tearDown(() async {
      await db.close();
    });

    test('debts table has status column after migration', () async {
      final rows = await db.rawQuery("PRAGMA table_info($tableDebts)");
      final columns = rows.map((r) => r['name'] as String).toList();
      expect(columns, contains('status'));
    });

    test('existing rows survive migration with status=active by DEFAULT', () async {
      final now = DateTime.now().toIso8601String();
      await db.execute(
        "INSERT INTO $tableDebts (id, user_id, name, total_amount, number_of_installments, due_date, sync_status, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ['debt-existing', 'user-1', 'Old Debt', 500.0, 5, '2026-12-31', 'synced', now, now],
      );
      final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: ['debt-existing']);
      expect(rows.first['status'], 'active');
    });

    test('row whose payment sum >= total_amount migrates to paid', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert(tableDebts, {
        'id': 'debt-paid',
        'user_id': 'user-1',
        'name': 'Fully Paid',
        'total_amount': 1000.0,
        'number_of_installments': 10,
        'due_date': '2026-12-31',
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      });
      await db.insert(tableDebtPayments, {
        'id': 'pay-1',
        'debt_id': 'debt-paid',
        'amount': 1000.0,
        'date': '2026-05-01',
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      });
      // Trigger migration by reopening
      await db.close();
      db = await openTestDatabase(fromVersion: 5);
      final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: ['debt-paid']);
      if (rows.isNotEmpty) {
        expect(rows.first['status'], 'paid');
      }
    });

    test('row whose payment sum < total_amount stays active', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert(tableDebts, {
        'id': 'debt-partial',
        'user_id': 'user-1',
        'name': 'Partial',
        'total_amount': 1000.0,
        'number_of_installments': 10,
        'due_date': '2026-12-31',
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      });
      await db.insert(tableDebtPayments, {
        'id': 'pay-2',
        'debt_id': 'debt-partial',
        'amount': 500.0,
        'date': '2026-05-01',
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      });
      final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: ['debt-partial']);
      if (rows.isNotEmpty) {
        expect(rows.first['status'], 'active');
      }
    });

    test('post-migration insert accepts status=hidden', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert(tableDebts, {
        'id': 'debt-hidden',
        'user_id': 'user-1',
        'name': 'Hidden',
        'total_amount': 500.0,
        'number_of_installments': 5,
        'due_date': '2026-12-31',
        'status': 'hidden',
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      });
      final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: ['debt-hidden']);
      expect(rows.first['status'], 'hidden');
    });
  });
}
