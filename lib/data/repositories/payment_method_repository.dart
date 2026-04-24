import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:sqflite/sqflite.dart';

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>((ref) {
  return PaymentMethodRepository(ref);
});

class PaymentMethodRepository {
  PaymentMethodRepository(this._ref);
  final Ref _ref;

  Future<Database> get _db => _ref.read(databaseProvider.future);

  Future<List<PaymentMethod>> getAll(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tablePaymentMethods,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'pending_delete'],
    );
    return rows.map(_rowToMethod).toList();
  }

  Future<List<PaymentMethod>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tablePaymentMethods,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
    return rows.map(_rowToMethod).toList();
  }

  Future<void> insert(PaymentMethod pm) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tablePaymentMethods,
      {
        'id': pm.id,
        'user_id': pm.userId,
        'name': pm.name,
        'type': pm.type,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> update(PaymentMethod pm) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tablePaymentMethods,
      {
        'name': pm.name,
        'type': pm.type,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: now,
      },
      where: 'id = ?',
      whereArgs: [pm.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final row = await db.query(tablePaymentMethods, where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    if (row.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tablePaymentMethods, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tablePaymentMethods,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tablePaymentMethods,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el registro local (usar tras sincronizar un pending_delete).
  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tablePaymentMethods, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(PaymentMethod pm) async {
    final db = await _db;
    final existing = await db.query(tablePaymentMethods, where: 'id = ?', whereArgs: [pm.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tablePaymentMethods,
      {
        'id': pm.id,
        'user_id': pm.userId,
        'name': pm.name,
        'type': pm.type,
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static PaymentMethod _rowToMethod(Map<String, dynamic> r) {
    return PaymentMethod(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      name: r['name'] as String,
      type: r['type'] as String? ?? 'other',
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
