import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

// ── helpers ─────────────────────────────────────────────────────────────────

Future<void> _insertReceivable(
  dynamic db, {
  String id = 'recv-1',
  String userId = 'user-1',
  double totalAmount = 1000.0,
  String status = 'active',
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableReceivables, {
    'id': id,
    'user_id': userId,
    'debtor_name': 'Test Debtor',
    'debtor_email': 'debtor@test.com',
    'total_amount': totalAmount,
    'status': status,
    columnSyncStatus: 'synced',
    columnUpdatedAt: now,
    'created_at': now,
  });
}

ReceivablePayment _makePayment({
  String id = 'pay-1',
  String receivableId = 'recv-1',
  double amount = 100.0,
  String? note,
  String syncStatus = 'synced',
}) {
  final now = DateTime.now();
  return ReceivablePayment(
    id: id,
    receivableId: receivableId,
    amount: amount,
    date: now,
    note: note,
    syncStatus: syncStatus,
  );
}

Future<Map<String, dynamic>> _getPaymentRow(dynamic db, String id) async {
  final rows = await db.query(
    tableReceivablePayments,
    where: 'id = ?',
    whereArgs: [id],
  );
  return rows.first as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _getReceivableRow(dynamic db, String id) async {
  final rows = await db.query(
    tableReceivables,
    where: 'id = ?',
    whereArgs: [id],
  );
  return rows.first as Map<String, dynamic>;
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late ReceivablePaymentRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ReceivablePaymentRepository(null, dbOverride: db);
    await _insertReceivable(db); // default recv-1, totalAmount=1000
  });

  tearDown(() async {
    await db.close();
  });

  // ── insert → getByReceivableId round-trip ─────────────────────────────────

  group('insert', () {
    test('insert → getByReceivableId round-trip', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 200.0));
      final payments = await repo.getByReceivableId('recv-1');
      expect(payments.length, 1);
      expect(payments.first.id, 'pay-1');
      expect(payments.first.amount, 200.0);
    });

    test('sets sync_status to pending_insert', () async {
      await repo.insert(_makePayment());
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row[columnSyncStatus], 'pending_insert');
    });

    test('stamps createdAt and updatedAt', () async {
      await repo.insert(_makePayment());
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row['created_at'], isNotNull);
      expect(row[columnUpdatedAt], isNotNull);
    });

    test('stores note field', () async {
      await repo.insert(_makePayment(note: 'Transfer via bank'));
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row['note'], 'Transfer via bank');
    });

    // ── overpayment guard ────────────────────────────────────────────────────

    test('blocks overpayment (existing 800 + new 300 > 1000)', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 800.0));
      // Mark as synced so it counts
      await db.update(
        tableReceivablePayments,
        {columnSyncStatus: 'synced'},
        where: 'id = ?',
        whereArgs: ['pay-1'],
      );
      expect(
        () => repo.insert(_makePayment(id: 'pay-2', amount: 300.0)),
        throwsA(isA<StateError>()),
      );
    });

    test('succeeds at exactly totalAmount (boundary — epsilon tolerant)', () async {
      // totalAmount=1000, inserting exactly 1000 in two payments: 600 + 400
      await repo.insert(_makePayment(id: 'pay-1', amount: 600.0));
      await db.update(
        tableReceivablePayments,
        {columnSyncStatus: 'synced'},
        where: 'id = ?',
        whereArgs: ['pay-1'],
      );
      await expectLater(
        repo.insert(_makePayment(id: 'pay-2', amount: 400.0)),
        completes,
      );
    });

    test('does not block when 1 cent below overpayment', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 999.99));
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row['amount'], 999.99);
    });

    // ── auto-settle ──────────────────────────────────────────────────────────

    test('auto-settles parent when remaining == 0', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 600.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);

      await repo.insert(_makePayment(id: 'pay-2', amount: 400.0));

      final row = await _getReceivableRow(db, 'recv-1');
      expect(row['status'], 'settled');
      expect(row[columnSyncStatus], 'pending_update');
    });

    test('does NOT auto-settle when remaining > 0', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 500.0));
      final row = await _getReceivableRow(db, 'recv-1');
      expect(row['status'], 'active');
    });

    test('auto-settle does not override writtenOff status', () async {
      // Set parent to writtenOff
      await db.update(tableReceivables, {'status': 'written_off'},
          where: 'id = ?', whereArgs: ['recv-1']);
      // A payment that would normally settle — but parent is writtenOff, should not flip
      await repo.insert(_makePayment(id: 'pay-1', amount: 1000.0));
      final row = await _getReceivableRow(db, 'recv-1');
      expect(row['status'], 'written_off');
    });

    test('auto-settle does not override hidden status', () async {
      await db.update(tableReceivables, {'status': 'hidden'},
          where: 'id = ?', whereArgs: ['recv-1']);
      await repo.insert(_makePayment(id: 'pay-1', amount: 1000.0));
      final row = await _getReceivableRow(db, 'recv-1');
      expect(row['status'], 'hidden');
    });

    test('parent sync_status becomes pending_update after auto-settle flip', () async {
      // Set parent to synced
      await db.update(tableReceivables, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['recv-1']);

      await repo.insert(_makePayment(id: 'pay-1', amount: 1000.0));

      final row = await _getReceivableRow(db, 'recv-1');
      expect(row[columnSyncStatus], 'pending_update');
    });
  });

  // ── update ────────────────────────────────────────────────────────────────

  group('update', () {
    test('sets sync_status to pending_update', () async {
      await repo.insert(_makePayment(amount: 100.0));
      await db.update(
        tableReceivablePayments,
        {columnSyncStatus: 'synced'},
        where: 'id = ?',
        whereArgs: ['pay-1'],
      );
      final updated = _makePayment(amount: 150.0);
      await repo.update(updated);
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row[columnSyncStatus], 'pending_update');
      expect(row['amount'], 150.0);
    });

    test('recalculates remaining (excludes own old amount)', () async {
      // Two payments: 400 + 500 = 900 paid, 100 remaining
      await repo.insert(_makePayment(id: 'pay-1', amount: 400.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      await repo.insert(_makePayment(id: 'pay-2', amount: 500.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-2']);

      // Raise pay-1 from 400 to 500: other payments=500, 500+500=1000 = totalAmount (ok)
      await repo.update(_makePayment(id: 'pay-1', amount: 500.0));
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row['amount'], 500.0);
    });

    test('blocks overpayment after recalc (excluding self)', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 400.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      await repo.insert(_makePayment(id: 'pay-2', amount: 500.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-2']);

      // Try to raise pay-1 to 600: other=500, 600+500=1100 > 1000 → overpayment
      expect(
        () => repo.update(_makePayment(id: 'pay-1', amount: 600.0)),
        throwsA(isA<StateError>()),
      );
    });

    test('auto-settles if new remaining == 0', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 400.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      await repo.insert(_makePayment(id: 'pay-2', amount: 500.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-2']);
      // Raise pay-1 to 500: 500+500=1000 = totalAmount → settle
      await repo.update(_makePayment(id: 'pay-1', amount: 500.0));
      final row = await _getReceivableRow(db, 'recv-1');
      expect(row['status'], 'settled');
    });

    test('reactivates parent if was settled and new remaining > 0', () async {
      // Fully pay first
      await repo.insert(_makePayment(id: 'pay-1', amount: 1000.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      // Confirm settled
      final before = await _getReceivableRow(db, 'recv-1');
      expect(before['status'], 'settled');

      // Reduce payment to 500 → remaining becomes 500 → reactivate
      await repo.update(_makePayment(id: 'pay-1', amount: 500.0));
      final after = await _getReceivableRow(db, 'recv-1');
      expect(after['status'], 'active');
    });
  });

  // ── delete ────────────────────────────────────────────────────────────────

  group('delete', () {
    test('hard-deletes when syncStatus is pending_insert', () async {
      await repo.insert(_makePayment()); // sets pending_insert
      await repo.delete('pay-1');
      final rows = await db.query(
        tableReceivablePayments,
        where: 'id = ?',
        whereArgs: ['pay-1'],
      );
      expect(rows, isEmpty);
    });

    test('sets pending_delete when syncStatus is synced', () async {
      await repo.insert(_makePayment());
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      await repo.delete('pay-1');
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row[columnSyncStatus], 'pending_delete');
    });

    test('delete removes payment and reactivates settled parent', () async {
      // Fully pay → settled
      await repo.insert(_makePayment(id: 'pay-1', amount: 1000.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      final before = await _getReceivableRow(db, 'recv-1');
      expect(before['status'], 'settled');

      // Delete the payment → remaining = 1000 > 0 → reactivate
      await repo.delete('pay-1');
      final after = await _getReceivableRow(db, 'recv-1');
      expect(after['status'], 'active');
    });

    test('pending_delete payment excluded from SUM (triggers reactivate if needed)', () async {
      // Insert 3 payments summing to 1000: pay-1=500 (synced), pay-2=300 (synced), pay-3=200 (synced)
      await repo.insert(_makePayment(id: 'pay-1', amount: 500.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      await repo.insert(_makePayment(id: 'pay-2', amount: 300.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-2']);
      await repo.insert(_makePayment(id: 'pay-3', amount: 200.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-3']);

      // Parent should be settled
      final before = await _getReceivableRow(db, 'recv-1');
      expect(before['status'], 'settled');

      // Delete pay-3 (synced → pending_delete), remaining = 500+300 = 800 > 0 → reactivate
      await repo.delete('pay-3');
      final after = await _getReceivableRow(db, 'recv-1');
      expect(after['status'], 'active');
    });
  });

  // ── getByReceivableId ──────────────────────────────────────────────────────

  group('getByReceivableId', () {
    test('excludes pending_delete rows', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 100.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'pending_delete'},
          where: 'id = ?', whereArgs: ['pay-1']);
      final payments = await repo.getByReceivableId('recv-1');
      expect(payments, isEmpty);
    });

    test('returns payments ordered by date DESC', () async {
      final p1 = ReceivablePayment(
        id: 'pay-1',
        receivableId: 'recv-1',
        amount: 100.0,
        date: DateTime(2026, 1, 1),
      );
      final p2 = ReceivablePayment(
        id: 'pay-2',
        receivableId: 'recv-1',
        amount: 200.0,
        date: DateTime(2026, 6, 1),
      );
      await repo.insert(p1);
      await repo.insert(p2);
      final payments = await repo.getByReceivableId('recv-1');
      expect(payments.first.id, 'pay-2'); // most recent first
      expect(payments.last.id, 'pay-1');
    });
  });

  // ── getPendingForPush ─────────────────────────────────────────────────────

  group('getPendingForPush', () {
    test('returns pending_insert rows', () async {
      await repo.insert(_makePayment());
      final pending = await repo.getPendingForPush();
      expect(pending.length, 1);
      expect(pending.first.syncStatus, 'pending_insert');
    });

    test('returns pending_update rows', () async {
      await repo.insert(_makePayment());
      await db.update(tableReceivablePayments,
          {columnSyncStatus: 'pending_update'},
          where: 'id = ?', whereArgs: ['pay-1']);
      final pending = await repo.getPendingForPush();
      expect(pending.length, 1);
      expect(pending.first.syncStatus, 'pending_update');
    });

    test('returns pending_delete rows', () async {
      await repo.insert(_makePayment());
      await db.update(tableReceivablePayments,
          {columnSyncStatus: 'pending_delete'},
          where: 'id = ?', whereArgs: ['pay-1']);
      final pending = await repo.getPendingForPush();
      expect(pending.length, 1);
      expect(pending.first.syncStatus, 'pending_delete');
    });

    test('does NOT return synced rows', () async {
      await repo.insert(_makePayment());
      await db.update(tableReceivablePayments, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['pay-1']);
      final pending = await repo.getPendingForPush();
      expect(pending, isEmpty);
    });
  });

  // ── markSynced ────────────────────────────────────────────────────────────

  group('markSynced', () {
    test('sets sync_status to synced', () async {
      await repo.insert(_makePayment());
      await repo.markSynced('pay-1');
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row[columnSyncStatus], 'synced');
    });
  });

  // ── upsertFromRemote ──────────────────────────────────────────────────────

  group('upsertFromRemote', () {
    test('inserts when row does not exist', () async {
      await repo.upsertFromRemote(_makePayment(amount: 300.0));
      final payments = await repo.getByReceivableId('recv-1');
      expect(payments.length, 1);
      expect(payments.first.syncStatus, 'synced');
    });

    test('overwrites synced local row', () async {
      await repo.upsertFromRemote(_makePayment(amount: 300.0));
      await repo.upsertFromRemote(_makePayment(amount: 500.0));
      final payments = await repo.getByReceivableId('recv-1');
      expect(payments.first.amount, 500.0);
    });

    test('skips dirty local row (local wins)', () async {
      await repo.insert(_makePayment(amount: 300.0));
      // local is pending_insert → dirty
      await repo.upsertFromRemote(_makePayment(amount: 999.0));
      final row = await _getPaymentRow(db, 'pay-1');
      expect(row['amount'], 300.0);
    });
  });

  // ── deleteLocal ───────────────────────────────────────────────────────────

  group('deleteLocal', () {
    test('hard-deletes row from DB', () async {
      await repo.insert(_makePayment());
      await repo.deleteLocal('pay-1');
      final rows = await db.query(
        tableReceivablePayments,
        where: 'id = ?',
        whereArgs: ['pay-1'],
      );
      expect(rows, isEmpty);
    });
  });

  // ── getTotalPaid ──────────────────────────────────────────────────────────

  group('getTotalPaid', () {
    test('returns 0 when no payments', () async {
      final total = await repo.getTotalPaid('recv-1');
      expect(total, 0.0);
    });

    test('sums non-deleted payments', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 300.0));
      await repo.insert(_makePayment(id: 'pay-2', amount: 200.0));
      final total = await repo.getTotalPaid('recv-1');
      expect(total, 500.0);
    });

    test('excludes pending_delete from sum', () async {
      await repo.insert(_makePayment(id: 'pay-1', amount: 300.0));
      await repo.insert(_makePayment(id: 'pay-2', amount: 200.0));
      await db.update(tableReceivablePayments, {columnSyncStatus: 'pending_delete'},
          where: 'id = ?', whereArgs: ['pay-2']);
      final total = await repo.getTotalPaid('recv-1');
      expect(total, 300.0);
    });
  });
}
