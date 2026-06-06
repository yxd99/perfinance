import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  group('v7 → v8 migration', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(fromVersion: 7);
    });

    tearDown(() async {
      await db.close();
    });

    test('receivables table is created with correct columns', () async {
      final rows =
          await db.rawQuery('PRAGMA table_info($tableReceivables)');
      final columns = rows.map((r) => r['name'] as String).toSet();
      expect(
        columns,
        containsAll([
          'id',
          'user_id',
          'debtor_name',
          'debtor_email',
          'total_amount',
          'description',
          'due_date',
          'status',
          'sync_status',
          'updated_at',
          'created_at',
        ]),
      );
    });

    test('receivable_payments table is created with correct columns',
        () async {
      final rows =
          await db.rawQuery('PRAGMA table_info($tableReceivablePayments)');
      final columns = rows.map((r) => r['name'] as String).toSet();
      expect(
        columns,
        containsAll([
          'id',
          'receivable_id',
          'amount',
          'date',
          'note',
          'sync_status',
          'updated_at',
          'created_at',
        ]),
      );
    });

    test('idx_receivables_user index exists', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_receivables_user'",
      );
      expect(rows, isNotEmpty);
    });

    test('idx_recv_payments_recv index exists', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_recv_payments_recv'",
      );
      expect(rows, isNotEmpty);
    });

    test('idx_recv_payments_sync index exists', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_recv_payments_sync'",
      );
      expect(rows, isNotEmpty);
    });

    test('deleting a receivable cascades to its payments (FK ON)', () async {
      final now = DateTime.now().toIso8601String();
      await db.execute('PRAGMA foreign_keys = ON');

      await db.insert(tableReceivables, {
        'id': 'recv-1',
        'user_id': 'user-1',
        'debtor_name': 'Test Debtor',
        'debtor_email': 'debtor@test.com',
        'total_amount': 500.0,
        'status': 'active',
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      await db.insert(tableReceivablePayments, {
        'id': 'pay-1',
        'receivable_id': 'recv-1',
        'amount': 100.0,
        'date': now,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });

      // Verify payment exists before delete
      final before = await db.query(
        tableReceivablePayments,
        where: 'receivable_id = ?',
        whereArgs: ['recv-1'],
      );
      expect(before, hasLength(1));

      // Delete the parent receivable
      await db.delete(tableReceivables, where: 'id = ?', whereArgs: ['recv-1']);

      // Payment must be cascade-deleted
      final after = await db.query(
        tableReceivablePayments,
        where: 'receivable_id = ?',
        whereArgs: ['recv-1'],
      );
      expect(after, isEmpty);
    });

    test('status defaults to active on fresh insert', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert(tableReceivables, {
        'id': 'recv-2',
        'user_id': 'user-1',
        'debtor_name': 'Another Debtor',
        'total_amount': 200.0,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });
      final rows = await db.query(
        tableReceivables,
        where: 'id = ?',
        whereArgs: ['recv-2'],
      );
      expect(rows.first['status'], 'active');
    });
  });
}
