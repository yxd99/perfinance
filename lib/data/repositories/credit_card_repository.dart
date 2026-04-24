import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:sqflite/sqflite.dart';

final creditCardRepositoryProvider = Provider<CreditCardRepository>((ref) {
  return CreditCardRepository(ref);
});

class CreditCardRepository {
  CreditCardRepository(this._ref);
  final Ref _ref;

  Future<Database> get _db => _ref.read(databaseProvider.future);

  Future<List<CreditCard>> getAll(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableCreditCards,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'pending_delete'],
    );
    return rows.map((r) => _rowToCard(r)).toList();
  }

  Future<List<CreditCard>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableCreditCards,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
    return rows.map((r) => _rowToCard(r)).toList();
  }

  Future<CreditCard?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(tableCreditCards, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToCard(rows.first);
  }

  Future<void> insert(CreditCard card) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableCreditCards,
      {
        'id': card.id,
        'user_id': card.userId,
        'alias': card.alias,
        'cut_off_day': card.cutOffDay,
        'management_fee': card.managementFee,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> update(CreditCard card) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableCreditCards,
      {
        'alias': card.alias,
        'cut_off_day': card.cutOffDay,
        'management_fee': card.managementFee,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: now,
      },
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final row = await db.query(tableCreditCards, where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    if (row.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tableCreditCards, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableCreditCards,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableCreditCards,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el registro local y datos asociados (usar tras sincronizar un pending_delete).
  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableCardPayments, where: 'card_id = ?', whereArgs: [id]);
    await db.delete(tableMinPaymentConfigs, where: 'card_id = ?', whereArgs: [id]);
    await db.delete(tableCreditCards, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(CreditCard card) async {
    final db = await _db;
    final existing = await db.query(tableCreditCards, where: 'id = ?', whereArgs: [card.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableCreditCards,
      {
        'id': card.id,
        'user_id': card.userId,
        'alias': card.alias,
        'cut_off_day': card.cutOffDay,
        'management_fee': card.managementFee,
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static CreditCard _rowToCard(Map<String, dynamic> r) {
    return CreditCard(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      alias: r['alias'] as String,
      cutOffDay: r['cut_off_day'] as int,
      managementFee: (r['management_fee'] as num).toDouble(),
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
