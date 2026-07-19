import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  group('v11 → v12 migration', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(fromVersion: 11);
    });

    tearDown(() async {
      await db.close();
    });

    test('v11 to v12 upgrade adds is_active to credit_cards defaulting to 1', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableCreditCards)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('is_active'),
          reason: 'is_active column must exist on credit_cards after v12 migration');

      final now = DateTime.now().toIso8601String();
      await db.insert(tableCreditCards, {
        'id': 'card-existing',
        'user_id': 'user-1',
        'alias': 'Old Card',
        'cut_off_day': 15,
        'management_fee': 0.0,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });
      final rows = await db.query(
        tableCreditCards,
        where: 'id = ?',
        whereArgs: ['card-existing'],
      ) as List<Map<String, dynamic>>;
      expect(rows.first['is_active'], equals(1),
          reason: 'is_active must default to 1 for pre-existing and new rows');
    });

    test('v11 to v12 upgrade adds status to automatic_payments defaulting to active', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableAutomaticPayments)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('status'),
          reason: 'status column must exist on automatic_payments after v12 migration');

      final now = DateTime.now().toIso8601String();
      await db.insert(tableAutomaticPayments, {
        'id': 'auto-existing',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 1000.0,
        'description': 'Pago tarjeta',
        'next_run_date': now,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });
      final rows = await db.query(
        tableAutomaticPayments,
        where: 'id = ?',
        whereArgs: ['auto-existing'],
      ) as List<Map<String, dynamic>>;
      expect(rows.first['status'], equals('active'),
          reason: 'status must default to active for pre-existing and new rows');
    });
  });

  group('fresh install (_onCreate) includes is_active and status', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh install has is_active column in credit_cards', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableCreditCards)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('is_active'),
          reason: 'fresh install must have is_active column on credit_cards');
    });

    test('fresh install has status column in automatic_payments', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableAutomaticPayments)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('status'),
          reason: 'fresh install must have status column on automatic_payments');
    });
  });
}
