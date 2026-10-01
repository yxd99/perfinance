import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:sqflite/sqflite.dart';

final automaticPaymentRepositoryProvider = Provider<AutomaticPaymentRepository>((ref) {
  return AutomaticPaymentRepository(ref);
});

class AutomaticPaymentRepository {
  AutomaticPaymentRepository(this._ref, {dynamic dbOverride}) : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<Database> get _db async {
    if (_dbOverride != null) return _dbOverride as Database;
    return _ref!.read(databaseProvider.future);
  }

  Future<List<AutomaticPayment>> getAll(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableAutomaticPayments,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'pending_delete'],
      orderBy: 'next_run_date ASC',
    );
    return rows.map(_rowTo).toList();
  }

  /// Pagos cuya próxima fecha de ejecución es hoy o ya pasó.
  Future<List<AutomaticPayment>> getDue(String userId, DateTime onOrBefore) async {
    final db = await _db;
    final dateStr = '${onOrBefore.year.toString().padLeft(4, '0')}-${onOrBefore.month.toString().padLeft(2, '0')}-${onOrBefore.day.toString().padLeft(2, '0')}';
    final rows = await db.query(
      tableAutomaticPayments,
      where: 'user_id = ? AND sync_status != ? AND substr(next_run_date, 1, 10) <= ?',
      whereArgs: [userId, 'pending_delete', dateStr],
      orderBy: 'next_run_date ASC',
    );
    return rows.map(_rowTo).toList();
  }

  Future<List<AutomaticPayment>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableAutomaticPayments,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
    return rows.map(_rowTo).toList();
  }

  Future<void> insert(AutomaticPayment p) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableAutomaticPayments,
      {
        'id': p.id,
        'user_id': p.userId,
        'payment_type': p.paymentType,
        'payment_ref': p.paymentRef,
        'amount': p.amount,
        'description': p.description,
        'next_run_date': p.nextRunDate.toIso8601String(),
        'payment_day_of_month': p.paymentDayOfMonth,
        'frequency': p.frequency,
        'status': p.status,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> updateNextRunDate(String id, DateTime nextRunDate) async {
    final db = await _db;
    await db.update(
      tableAutomaticPayments,
      {
        'next_run_date': nextRunDate.toIso8601String(),
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> update(AutomaticPayment p) async {
    final db = await _db;
    await db.update(
      tableAutomaticPayments,
      {
        'payment_type': p.paymentType,
        'payment_ref': p.paymentRef,
        'amount': p.amount,
        'description': p.description,
        'next_run_date': p.nextRunDate.toIso8601String(),
        'payment_day_of_month': p.paymentDayOfMonth,
        'frequency': p.frequency,
        'status': p.status,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final row = await db.query(tableAutomaticPayments, where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    if (row.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tableAutomaticPayments, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableAutomaticPayments,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableAutomaticPayments,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableAutomaticPayments, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(AutomaticPayment p) async {
    final db = await _db;
    final existing = await db.query(tableAutomaticPayments, where: 'id = ?', whereArgs: [p.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableAutomaticPayments,
      {
        'id': p.id,
        'user_id': p.userId,
        'payment_type': p.paymentType,
        'payment_ref': p.paymentRef,
        'amount': p.amount,
        'description': p.description,
        'next_run_date': p.nextRunDate.toIso8601String(),
        'payment_day_of_month': p.paymentDayOfMonth,
        'frequency': p.frequency,
        'status': p.status,
        columnSyncStatus: 'synced',
        columnUpdatedAt: p.updatedAt ?? now,
        'created_at': p.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Pausa (status='paused') todos los pagos automáticos activos ligados a la tarjeta [cardId].
  /// Idempotente: solo afecta filas con status='active'; no reactiva pausados existentes.
  Future<void> pauseAllForCard(String cardId) async {
    final db = await _db;
    await db.update(
      tableAutomaticPayments,
      {
        'status': 'paused',
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'payment_type = ? AND payment_ref = ? AND status = ?',
      whereArgs: ['credit_card', cardId, 'active'],
    );
  }

  static AutomaticPayment _rowTo(Map<String, dynamic> r) {
    return AutomaticPayment.fromMap({
      ...r,
      'sync_status': r[columnSyncStatus],
      'updated_at': r[columnUpdatedAt],
    });
  }
}
