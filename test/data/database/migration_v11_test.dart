import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  group('v10 → v11 migration', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase(fromVersion: 10);
    });

    tearDown(() async {
      await db.close();
    });

    test('v10 to v11 upgrade adds effective_day column to min_payment_configs', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableMinPaymentConfigs)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('effective_day'),
          reason: 'effective_day column must exist after v11 migration');
    });

    test('effective_day defaults to 1 on existing rows', () async {
      final now = DateTime.now().toIso8601String();
      // Insert a min_payment_config row (post-migration, should have effective_day = 1 by default)
      await db.insert(tableMinPaymentConfigs, {
        'id': 'cfg-1',
        'card_id': 'card-1',
        'amount': 500.0,
        'year': 2026,
        'month': 6,
        'sync_status': 'synced',
        'updated_at': now,
        'created_at': now,
      });
      final rows = await db.query(
        tableMinPaymentConfigs,
        where: 'id = ?',
        whereArgs: ['cfg-1'],
      ) as List<Map<String, dynamic>>;
      expect(rows.first['effective_day'], equals(1),
          reason: 'effective_day must default to 1');
    });

    test('new rows can store effective_day values between 1 and 31', () async {
      final now = DateTime.now().toIso8601String();
      for (final day in [1, 15, 25, 28, 31]) {
        await db.insert(tableMinPaymentConfigs, {
          'id': 'cfg-day-$day',
          'card_id': 'card-1',
          'amount': 300.0,
          'year': 2026,
          'month': day, // use month as unique key per row
          'effective_day': day,
          'sync_status': 'synced',
          'updated_at': now,
          'created_at': now,
        });
        final rows = await db.query(
          tableMinPaymentConfigs,
          where: 'id = ?',
          whereArgs: ['cfg-day-$day'],
        ) as List<Map<String, dynamic>>;
        expect(rows.first['effective_day'], equals(day),
            reason: 'effective_day=$day must be stored correctly');
      }
    });
  });

  group('fresh install (_onCreate) includes effective_day', () {
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh install has effective_day column in min_payment_configs', () async {
      final cols = await db.rawQuery(
        'PRAGMA table_info($tableMinPaymentConfigs)',
      ) as List<Map<String, dynamic>>;
      final colNames = cols.map((c) => c['name'] as String).toSet();
      expect(colNames, contains('effective_day'),
          reason: 'fresh install must have effective_day column');
    });
  });
}
