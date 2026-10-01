import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:sqflite/sqflite.dart';

final minPaymentConfigRepositoryProvider = Provider<MinPaymentConfigRepository>((ref) {
  return MinPaymentConfigRepository(ref);
});

class MinPaymentConfigRepository {
  MinPaymentConfigRepository(this._ref, {dynamic dbOverride})
      : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<dynamic> get _db async {
    if (_dbOverride != null) return _dbOverride;
    return _ref!.read(databaseProvider.future);
  }

  Future<MinPaymentConfig?> getForCardAndMonth(String cardId, int year, int month) async {
    final db = await _db;
    final rows = await db.query(
      tableMinPaymentConfigs,
      where: 'card_id = ? AND year = ? AND month = ?',
      whereArgs: [cardId, year, month],
    ) as List<Map<String, dynamic>>;
    if (rows.isEmpty) return null;
    return _rowToConfig(rows.first);
  }

  Future<List<MinPaymentConfig>> getPendingForPush() async {
    final db = await _db;
    final rows = await db.query(
      tableMinPaymentConfigs,
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    ) as List<Map<String, dynamic>>;
    return rows.map(_rowToConfig).toList();
  }

  Future<void> insert(MinPaymentConfig c) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableMinPaymentConfigs,
      {
        'id': c.id,
        'card_id': c.cardId,
        'amount': c.amount,
        'year': c.year,
        'month': c.month,
        'effective_day': c.effectiveDay,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(MinPaymentConfig c) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      tableMinPaymentConfigs,
      {
        'amount': c.amount,
        'effective_day': c.effectiveDay,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: now,
      },
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableMinPaymentConfigs,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertFromRemote(MinPaymentConfig c) async {
    final db = await _db;
    final existing = await db.query(
      tableMinPaymentConfigs,
      where: 'id = ?',
      whereArgs: [c.id],
    ) as List<Map<String, dynamic>>;
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableMinPaymentConfigs,
      {
        'id': c.id,
        'card_id': c.cardId,
        'amount': c.amount,
        'year': c.year,
        'month': c.month,
        'effective_day': c.effectiveDay,
        columnSyncStatus: 'synced',
        columnUpdatedAt: c.updatedAt ?? now,
        'created_at': c.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static MinPaymentConfig _rowToConfig(Map<String, dynamic> r) {
    return MinPaymentConfig(
      id: r['id'] as String,
      cardId: r['card_id'] as String,
      amount: (r['amount'] as num).toDouble(),
      year: r['year'] as int,
      month: r['month'] as int,
      effectiveDay: r['effective_day'] as int? ?? 1,
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
