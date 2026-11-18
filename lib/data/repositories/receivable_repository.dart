import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/receivable.dart';

final receivableRepositoryProvider = Provider<ReceivableRepository>((ref) {
  return ReceivableRepository(ref);
});

class ReceivableRepository {
  ReceivableRepository(this._ref, {dynamic dbOverride}) : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<dynamic> get _db async {
    if (_dbOverride != null) return _dbOverride;
    return _ref!.read(databaseProvider.future);
  }

  // ── queries ────────────────────────────────────────────────────────────────

  Future<List<Receivable>> getAll(
    String userId, {
    ReceivableStatus? status,
  }) async {
    final db = await _db;
    String where;
    List<dynamic> whereArgs;

    if (status != null) {
      where = 'user_id = ? AND $columnSyncStatus != ? AND status = ?';
      whereArgs = [userId, 'pending_delete', status.wire];
    } else {
      // Default: exclude pending_delete AND hidden
      where = 'user_id = ? AND $columnSyncStatus != ? AND status != ?';
      whereArgs = [userId, 'pending_delete', 'hidden'];
    }

    final rawRows = await db.query(
      tableReceivables,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    ) as List<Map<String, dynamic>>;
    return rawRows.map(_rowToReceivable).toList();
  }

  Future<Receivable?> getById(String id) async {
    final db = await _db;
    final rows =
        await db.query(tableReceivables, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToReceivable(rows.first);
  }

  Future<List<Receivable>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
          tableReceivables,
          where: 'user_id = ? AND $columnSyncStatus != ?',
          whereArgs: [userId, 'synced'],
        ) as List<Map<String, dynamic>>;
    return rows.map(_rowToReceivable).toList();
  }

  // ── writes ─────────────────────────────────────────────────────────────────

  Future<void> insert(Receivable r) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(tableReceivables, {
      'id': r.id,
      'user_id': r.userId,
      'debtor_name': r.debtorName,
      'debtor_email': r.debtorEmail,
      'total_amount': r.totalAmount,
      'description': r.description,
      'due_date': r.dueDate?.toIso8601String(),
      'status': ReceivableStatus.active.wire,
      columnSyncStatus: 'pending_insert',
      columnUpdatedAt: now,
      'created_at': now,
    });
  }

  Future<void> update(Receivable r) async {
    final db = await _db;
    await db.update(
      tableReceivables,
      {
        'debtor_name': r.debtorName,
        'debtor_email': r.debtorEmail,
        'total_amount': r.totalAmount,
        'description': r.description,
        'due_date': r.dueDate?.toIso8601String(),
        'status': r.status.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final rows =
        await db.query(tableReceivables, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    if (rows.first[columnSyncStatus] == 'pending_insert') {
      // Explicitly delete children first (mirrors debt_repository pattern; more reliable than FK cascade alone)
      await db.delete(
          tableReceivablePayments, where: 'receivable_id = ?', whereArgs: [id]);
      await db.delete(tableReceivables, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableReceivables,
        {
          columnSyncStatus: 'pending_delete',
          columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableReceivables,
      {
        columnSyncStatus: 'synced',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableReceivables, where: 'id = ?', whereArgs: [id]);
    // CASCADE handles child payments, but explicit delete is safe as a fallback
  }

  Future<void> upsertFromRemote(Receivable r) async {
    final db = await _db;
    final existing =
        await db.query(tableReceivables, where: 'id = ?', whereArgs: [r.id]);
    if (existing.isNotEmpty &&
        (existing.first[columnSyncStatus] as String?) != 'synced') {
      return; // local wins
    }
    final now = DateTime.now().toIso8601String();
    await upsertRowById(
      db,
      tableReceivables,
      {
        'id': r.id,
        'user_id': r.userId,
        'debtor_name': r.debtorName,
        'debtor_email': r.debtorEmail,
        'total_amount': r.totalAmount,
        'description': r.description,
        'due_date': r.dueDate?.toIso8601String(),
        'status': r.status.wire,
        columnSyncStatus: 'synced',
        columnUpdatedAt: r.updatedAt ?? now,
        'created_at': r.createdAt ?? now,
      },
      );
  }

  // ── status transitions ─────────────────────────────────────────────────────

  Future<void> settle(String id) async {
    final db = await _db;
    await db.update(
      tableReceivables,
      {
        'status': ReceivableStatus.settled.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reactivate(String id) async {
    final db = await _db;
    await db.update(
      tableReceivables,
      {
        'status': ReceivableStatus.active.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hide(String id) async {
    final db = await _db;
    await db.update(
      tableReceivables,
      {
        'status': ReceivableStatus.hidden.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── row mapper ─────────────────────────────────────────────────────────────

  static Receivable _rowToReceivable(Map<String, dynamic> r) {
    return Receivable(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      debtorName: r['debtor_name'] as String,
      debtorEmail: r['debtor_email'] as String?,
      totalAmount: (r['total_amount'] as num).toDouble(),
      description: r['description'] as String?,
      dueDate: r['due_date'] != null
          ? DateTime.parse(r['due_date'] as String)
          : null,
      status: ReceivableStatusX.fromWire(r['status'] as String?),
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
