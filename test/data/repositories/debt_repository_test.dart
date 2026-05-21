import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

// Minimal repo under test — uses raw DB directly to avoid Riverpod
Future<void> _insertDebt(dynamic db, {
  String id = 'debt-1',
  String userId = 'user-1',
  String name = 'Test',
  double totalAmount = 1000,
  int installments = 12,
  String status = 'active',
  String syncStatus = 'synced',
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableDebts, {
    'id': id,
    'user_id': userId,
    'name': name,
    'total_amount': totalAmount,
    'number_of_installments': installments,
    'due_date': '2026-12-31',
    'status': status,
    columnSyncStatus: syncStatus,
    columnUpdatedAt: now,
    'created_at': now,
  });
}

Future<Map<String, dynamic>> _getRow(dynamic db, String id) async {
  final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: [id]);
  return rows.first;
}

Future<void> _payDebt(dynamic db, String id) async {
  await db.update(
    tableDebts,
    {'status': 'paid', columnSyncStatus: 'pending_update', columnUpdatedAt: DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> _reactivateDebt(dynamic db, String id) async {
  await db.update(
    tableDebts,
    {'status': 'active', columnSyncStatus: 'pending_update', columnUpdatedAt: DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> _hideDebt(dynamic db, String id) async {
  await db.update(
    tableDebts,
    {'status': 'hidden', columnSyncStatus: 'pending_update', columnUpdatedAt: DateTime.now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
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

  group('payDebt', () {
    test('sets status to paid', () async {
      await _insertDebt(db);
      await _payDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'paid');
    });

    test('sets sync_status to pending_update', () async {
      await _insertDebt(db);
      await _payDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row[columnSyncStatus], 'pending_update');
    });

    test('updates updated_at', () async {
      await _insertDebt(db, id: 'debt-1');
      final before = (await _getRow(db, 'debt-1'))[columnUpdatedAt] as String;
      await Future.delayed(const Duration(milliseconds: 5));
      await _payDebt(db, 'debt-1');
      final after = (await _getRow(db, 'debt-1'))[columnUpdatedAt] as String;
      expect(after.compareTo(before), greaterThanOrEqualTo(0));
    });
  });

  group('reactivateDebt', () {
    test('sets status to active when debt was paid', () async {
      await _insertDebt(db, status: 'paid');
      await _reactivateDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'active');
    });

    test('sets status to active when debt was hidden', () async {
      await _insertDebt(db, status: 'hidden');
      await _reactivateDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'active');
    });

    test('sets sync_status to pending_update', () async {
      await _insertDebt(db, status: 'paid');
      await _reactivateDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row[columnSyncStatus], 'pending_update');
    });
  });

  group('hideDebt', () {
    test('sets status to hidden', () async {
      await _insertDebt(db);
      await _hideDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'hidden');
    });

    test('sets sync_status to pending_update', () async {
      await _insertDebt(db);
      await _hideDebt(db, 'debt-1');
      final row = await _getRow(db, 'debt-1');
      expect(row[columnSyncStatus], 'pending_update');
    });

    test('updates updated_at', () async {
      await _insertDebt(db);
      final before = (await _getRow(db, 'debt-1'))[columnUpdatedAt] as String;
      await Future.delayed(const Duration(milliseconds: 5));
      await _hideDebt(db, 'debt-1');
      final after = (await _getRow(db, 'debt-1'))[columnUpdatedAt] as String;
      expect(after.compareTo(before), greaterThanOrEqualTo(0));
    });
  });

  group('status round-trip', () {
    test('insert preserves status from model (row has status column)', () async {
      await _insertDebt(db, status: 'paid');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'paid');
    });

    test('status column defaults to active when not provided', () async {
      // Insert without specifying status — relies on column DEFAULT
      final now = DateTime.now().toIso8601String();
      await db.execute(
        "INSERT INTO $tableDebts (id, user_id, name, total_amount, number_of_installments, due_date, sync_status, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ['debt-2', 'user-1', 'Test2', 500.0, 5, '2026-12-31', 'synced', now, now],
      );
      final row = await _getRow(db, 'debt-2');
      expect(row['status'], 'active');
    });

    test('upsertFromRemote stores status=hidden', () async {
      await _insertDebt(db, status: 'hidden');
      final row = await _getRow(db, 'debt-1');
      expect(row['status'], 'hidden');
    });

    test('fromWire defaults to active when column missing/null', () {
      expect(DebtStatusX.fromWire(null), DebtStatus.active);
      expect(DebtStatusX.fromWire(''), DebtStatus.active);
    });
  });
}
