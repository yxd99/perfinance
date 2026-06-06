import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../../helpers/db_helper.dart';

// ── helpers ─────────────────────────────────────────────────────────────────

Receivable _makeReceivable({
  String id = 'recv-1',
  String userId = 'user-1',
  String debtorName = 'John Doe',
  String? debtorEmail = 'john@example.com',
  double totalAmount = 1000.0,
  ReceivableStatus status = ReceivableStatus.active,
  String syncStatus = 'synced',
}) {
  final now = DateTime.now().toIso8601String();
  return Receivable(
    id: id,
    userId: userId,
    debtorName: debtorName,
    debtorEmail: debtorEmail,
    totalAmount: totalAmount,
    status: status,
    syncStatus: syncStatus,
    updatedAt: now,
    createdAt: now,
  );
}

Future<Map<String, dynamic>> _getRow(dynamic db, String id) async {
  final rows =
      await db.query(tableReceivables, where: 'id = ?', whereArgs: [id]);
  return rows.first;
}


// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late ReceivableRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ReceivableRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── insert ────────────────────────────────────────────────────────────────

  group('insert', () {
    test('sets sync_status to pending_insert', () async {
      await repo.insert(_makeReceivable());
      final row = await _getRow(db, 'recv-1');
      expect(row[columnSyncStatus], 'pending_insert');
    });

    test('stamps createdAt and updatedAt', () async {
      await repo.insert(_makeReceivable());
      final row = await _getRow(db, 'recv-1');
      expect(row['created_at'], isNotNull);
      expect(row[columnUpdatedAt], isNotNull);
    });

    test('stores all fields correctly', () async {
      await repo.insert(_makeReceivable(
        id: 'recv-2',
        debtorName: 'Jane',
        debtorEmail: 'jane@example.com',
        totalAmount: 500.0,
      ));
      final row = await _getRow(db, 'recv-2');
      expect(row['debtor_name'], 'Jane');
      expect(row['debtor_email'], 'jane@example.com');
      expect(row['total_amount'], 500.0);
      expect(row['status'], 'active');
    });
  });

  // ── getById ───────────────────────────────────────────────────────────────

  group('getById', () {
    test('returns receivable when found', () async {
      await repo.insert(_makeReceivable());
      final r = await repo.getById('recv-1');
      expect(r, isNotNull);
      expect(r!.id, 'recv-1');
      expect(r.debtorName, 'John Doe');
    });

    test('returns null when not found', () async {
      final r = await repo.getById('nonexistent');
      expect(r, isNull);
    });

    test('insert → getById round-trip preserves all fields', () async {
      final original = _makeReceivable(
        id: 'recv-rt',
        debtorEmail: 'rt@example.com',
        totalAmount: 750.0,
      );
      await repo.insert(original);
      final fetched = await repo.getById('recv-rt');
      expect(fetched!.userId, original.userId);
      expect(fetched.debtorEmail, original.debtorEmail);
      expect(fetched.totalAmount, original.totalAmount);
      expect(fetched.status, ReceivableStatus.active);
      expect(fetched.syncStatus, 'pending_insert');
    });
  });

  // ── getAll ────────────────────────────────────────────────────────────────

  group('getAll', () {
    test('filters by userId', () async {
      await repo.insert(_makeReceivable(id: 'r1', userId: 'user-1'));
      await repo.insert(_makeReceivable(id: 'r2', userId: 'user-2'));
      final results = await repo.getAll('user-1');
      expect(results.length, 1);
      expect(results.first.id, 'r1');
    });

    test('excludes pending_delete rows by default', () async {
      await repo.insert(_makeReceivable(id: 'r1'));
      // Manually mark as pending_delete
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'pending_delete'},
        where: 'id = ?',
        whereArgs: ['r1'],
      );
      final results = await repo.getAll('user-1');
      expect(results, isEmpty);
    });

    test('filters by status when provided', () async {
      await repo.insert(_makeReceivable(id: 'r1', status: ReceivableStatus.active));
      await repo.insert(_makeReceivable(id: 'r2', status: ReceivableStatus.settled));
      // Force settled status directly (insert always sets active)
      await db.update(
        tableReceivables,
        {'status': 'settled'},
        where: 'id = ?',
        whereArgs: ['r2'],
      );
      final active = await repo.getAll('user-1', status: ReceivableStatus.active);
      expect(active.length, 1);
      expect(active.first.id, 'r1');

      final settled = await repo.getAll('user-1', status: ReceivableStatus.settled);
      expect(settled.length, 1);
      expect(settled.first.id, 'r2');
    });

    test('excludes hidden rows by default (no status filter)', () async {
      await repo.insert(_makeReceivable(id: 'r1'));
      await repo.insert(_makeReceivable(id: 'r2'));
      await db.update(
        tableReceivables,
        {'status': 'hidden'},
        where: 'id = ?',
        whereArgs: ['r2'],
      );
      final results = await repo.getAll('user-1');
      expect(results.length, 1);
      expect(results.first.id, 'r1');
    });

    test('includes hidden rows when status=hidden is explicitly requested', () async {
      await repo.insert(_makeReceivable(id: 'r1'));
      await db.update(
        tableReceivables,
        {'status': 'hidden'},
        where: 'id = ?',
        whereArgs: ['r1'],
      );
      final results = await repo.getAll('user-1', status: ReceivableStatus.hidden);
      expect(results.length, 1);
      expect(results.first.status, ReceivableStatus.hidden);
    });
  });

  // ── update ────────────────────────────────────────────────────────────────

  group('update', () {
    test('changes fields and sets pending_update', () async {
      await repo.insert(_makeReceivable());
      final updated = _makeReceivable(
        debtorName: 'Updated Name',
        totalAmount: 2000.0,
      );
      await repo.update(updated);
      final row = await _getRow(db, 'recv-1');
      expect(row['debtor_name'], 'Updated Name');
      expect(row['total_amount'], 2000.0);
      expect(row[columnSyncStatus], 'pending_update');
    });

    test('stamps updatedAt', () async {
      await repo.insert(_makeReceivable());
      final before = (await _getRow(db, 'recv-1'))[columnUpdatedAt] as String;
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.update(_makeReceivable());
      final after = (await _getRow(db, 'recv-1'))[columnUpdatedAt] as String;
      expect(after.compareTo(before), greaterThanOrEqualTo(0));
    });
  });

  // ── delete ────────────────────────────────────────────────────────────────

  group('delete', () {
    test('hard-deletes when syncStatus is pending_insert', () async {
      await repo.insert(_makeReceivable());
      // insert sets pending_insert
      await repo.delete('recv-1');
      final rows =
          await db.query(tableReceivables, where: 'id = ?', whereArgs: ['recv-1']);
      expect(rows, isEmpty);
    });

    test('sets pending_delete when syncStatus is synced', () async {
      // Insert then force-set to synced
      await repo.insert(_makeReceivable());
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'synced'},
        where: 'id = ?',
        whereArgs: ['recv-1'],
      );
      await repo.delete('recv-1');
      final row = await _getRow(db, 'recv-1');
      expect(row[columnSyncStatus], 'pending_delete');
    });

    test('hard-delete also cascades to payments when pending_insert', () async {
      await repo.insert(_makeReceivable());
      // Insert a child payment directly
      final now = DateTime.now().toIso8601String();
      await db.insert(tableReceivablePayments, {
        'id': 'pay-1',
        'receivable_id': 'recv-1',
        'amount': 100.0,
        'date': now,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      });
      await repo.delete('recv-1');
      final payments = await db.query(
        tableReceivablePayments,
        where: 'receivable_id = ?',
        whereArgs: ['recv-1'],
      );
      expect(payments, isEmpty);
    });
  });

  // ── upsertFromRemote ──────────────────────────────────────────────────────

  group('upsertFromRemote', () {
    test('inserts when row does not exist', () async {
      await repo.upsertFromRemote(_makeReceivable());
      final r = await repo.getById('recv-1');
      expect(r, isNotNull);
      expect(r!.syncStatus, 'synced');
    });

    test('overwrites synced local row with remote data', () async {
      await repo.upsertFromRemote(_makeReceivable(debtorName: 'Old'));
      await repo.upsertFromRemote(_makeReceivable(debtorName: 'New'));
      final r = await repo.getById('recv-1');
      expect(r!.debtorName, 'New');
    });

    test('skips dirty local row (local wins)', () async {
      // Insert as pending_update (dirty)
      await repo.insert(_makeReceivable(debtorName: 'Local'));
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'pending_update', 'debtor_name': 'Local'},
        where: 'id = ?',
        whereArgs: ['recv-1'],
      );
      // Remote tries to overwrite
      await repo.upsertFromRemote(_makeReceivable(debtorName: 'Remote'));
      final r = await repo.getById('recv-1');
      expect(r!.debtorName, 'Local');
    });
  });

  // ── getPendingForPush ─────────────────────────────────────────────────────

  group('getPendingForPush', () {
    test('returns pending_insert and pending_update rows', () async {
      await repo.insert(_makeReceivable(id: 'r1')); // pending_insert
      await repo.insert(_makeReceivable(id: 'r2'));
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'pending_update'},
        where: 'id = ?',
        whereArgs: ['r2'],
      );
      await repo.insert(_makeReceivable(id: 'r3'));
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'synced'},
        where: 'id = ?',
        whereArgs: ['r3'],
      );
      final pending = await repo.getPendingForPush('user-1');
      final ids = pending.map((r) => r.id).toSet();
      expect(ids, containsAll(['r1', 'r2']));
      expect(ids, isNot(contains('r3')));
    });

    test('returns pending_delete rows', () async {
      await repo.insert(_makeReceivable(id: 'r1'));
      await db.update(
        tableReceivables,
        {columnSyncStatus: 'pending_delete'},
        where: 'id = ?',
        whereArgs: ['r1'],
      );
      final pending = await repo.getPendingForPush('user-1');
      expect(pending.length, 1);
      expect(pending.first.syncStatus, 'pending_delete');
    });
  });

  // ── markSynced ────────────────────────────────────────────────────────────

  group('markSynced', () {
    test('sets sync_status to synced', () async {
      await repo.insert(_makeReceivable());
      await repo.markSynced('recv-1');
      final row = await _getRow(db, 'recv-1');
      expect(row[columnSyncStatus], 'synced');
    });
  });

  // ── status transitions ────────────────────────────────────────────────────

  group('settle', () {
    test('sets status to settled and sync_status to pending_update', () async {
      await repo.insert(_makeReceivable());
      await repo.settle('recv-1');
      final row = await _getRow(db, 'recv-1');
      expect(row['status'], 'settled');
      expect(row[columnSyncStatus], 'pending_update');
    });
  });

  group('reactivate', () {
    test('sets status to active and sync_status to pending_update', () async {
      await repo.insert(_makeReceivable());
      await db.update(
        tableReceivables,
        {'status': 'settled'},
        where: 'id = ?',
        whereArgs: ['recv-1'],
      );
      await repo.reactivate('recv-1');
      final row = await _getRow(db, 'recv-1');
      expect(row['status'], 'active');
      expect(row[columnSyncStatus], 'pending_update');
    });
  });

  group('hide', () {
    test('sets status to hidden and sync_status to pending_update', () async {
      await repo.insert(_makeReceivable());
      await repo.hide('recv-1');
      final row = await _getRow(db, 'recv-1');
      expect(row['status'], 'hidden');
      expect(row[columnSyncStatus], 'pending_update');
    });
  });

  group('deleteLocal', () {
    test('hard-deletes row from DB', () async {
      await repo.insert(_makeReceivable());
      await repo.deleteLocal('recv-1');
      final rows =
          await db.query(tableReceivables, where: 'id = ?', whereArgs: ['recv-1']);
      expect(rows, isEmpty);
    });
  });
}
