import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:sqflite/sqflite.dart';

final cardPaymentRepositoryProvider = Provider<CardPaymentRepository>((ref) {
  return CardPaymentRepository(ref);
});

class CardPaymentRepository {
  CardPaymentRepository(this._ref, {dynamic dbOverride})
      : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<dynamic> get _db async {
    if (_dbOverride != null) return _dbOverride;
    return _ref!.read(databaseProvider.future);
  }

  Future<List<CardPayment>> getByCardId(String cardId) async {
    final db = await _db;
    final rows = await db.query(
      tableCardPayments,
      where: 'card_id = ? AND sync_status != ?',
      whereArgs: [cardId, 'pending_delete'],
      orderBy: 'date DESC',
    ) as List<Map<String, dynamic>>;
    return rows.map(_rowToPayment).toList();
  }

  Future<List<CardPayment>> getPendingForPush() async {
    final db = await _db;
    final rows = await db.query(
      tableCardPayments,
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    ) as List<Map<String, dynamic>>;
    return rows.map(_rowToPayment).toList();
  }

  Future<List<CardPayment>> getByCardIdInMonth(String cardId, int year, int month) async {
    final db = await _db;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.query(
      tableCardPayments,
      where: 'card_id = ? AND date >= ? AND date < ? AND sync_status != ?',
      whereArgs: [cardId, start, end, 'pending_delete'],
    ) as List<Map<String, dynamic>>;
    return rows.map(_rowToPayment).toList();
  }

  Future<void> insert(CardPayment p) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableCardPayments,
      {
        'id': p.id,
        'card_id': p.cardId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> update(CardPayment p) async {
    final db = await _db;
    await db.update(
      tableCardPayments,
      {
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableCardPayments, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markPendingDelete(String id) async {
    final db = await _db;
    await db.update(
      tableCardPayments,
      {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableCardPayments,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertFromRemote(CardPayment p) async {
    final db = await _db;
    final existing = await db.query(
      tableCardPayments,
      where: 'id = ?',
      whereArgs: [p.id],
    ) as List<Map<String, dynamic>>;
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableCardPayments,
      {
        'id': p.id,
        'card_id': p.cardId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        columnSyncStatus: 'synced',
        columnUpdatedAt: p.updatedAt ?? now,
        'created_at': p.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static CardPayment _rowToPayment(Map<String, dynamic> r) {
    return CardPayment(
      id: r['id'] as String,
      cardId: r['card_id'] as String,
      amount: (r['amount'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
