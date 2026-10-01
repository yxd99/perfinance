import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:sqflite/sqflite.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref);
});

class DebtRepository {
  DebtRepository(this._ref);
  final Ref _ref;

  Future<Database> get _db => _ref.read(databaseProvider.future);

  Future<List<Debt>> getAll(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableDebts,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'pending_delete'],
      orderBy: 'due_date ASC',
    );
    return rows.map(_rowToDebt).toList();
  }

  Future<Debt?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(tableDebts, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToDebt(rows.first);
  }

  Future<List<Debt>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableDebts,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
    return rows.map(_rowToDebt).toList();
  }

  Future<void> insert(Debt d) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableDebts,
      {
        'id': d.id,
        'user_id': d.userId,
        'name': d.name,
        'total_amount': d.totalAmount,
        'number_of_installments': d.numberOfInstallments,
        'due_date': d.dueDate.toIso8601String(),
        'status': d.status.wire,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> update(Debt d) async {
    final db = await _db;
    await db.update(
      tableDebts,
      {
        'name': d.name,
        'total_amount': d.totalAmount,
        'number_of_installments': d.numberOfInstallments,
        'due_date': d.dueDate.toIso8601String(),
        'status': d.status.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [d.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final row = await db.query(tableDebts, where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    if (row.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tableDebts, where: 'id = ?', whereArgs: [id]);
      await db.delete(tableDebtPayments, where: 'debt_id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableDebts,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableDebts,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableDebtPayments, where: 'debt_id = ?', whereArgs: [id]);
    await db.delete(tableDebts, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(Debt d) async {
    final db = await _db;
    final existing = await db.query(tableDebts, where: 'id = ?', whereArgs: [d.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableDebts,
      {
        'id': d.id,
        'user_id': d.userId,
        'name': d.name,
        'total_amount': d.totalAmount,
        'number_of_installments': d.numberOfInstallments,
        'due_date': d.dueDate.toIso8601String(),
        'status': d.status.wire,
        columnSyncStatus: 'synced',
        columnUpdatedAt: d.updatedAt ?? now,
        'created_at': d.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> payDebt(String id) async {
    final db = await _db;
    await db.update(
      tableDebts,
      {
        'status': DebtStatus.paid.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reactivateDebt(String id) async {
    final db = await _db;
    await db.update(
      tableDebts,
      {
        'status': DebtStatus.active.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hideDebt(String id) async {
    final db = await _db;
    await db.update(
      tableDebts,
      {
        'status': DebtStatus.hidden.wire,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Debt _rowToDebt(Map<String, dynamic> r) {
    return Debt(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      name: r['name'] as String,
      totalAmount: (r['total_amount'] as num).toDouble(),
      numberOfInstallments: r['number_of_installments'] as int,
      dueDate: DateTime.parse(r['due_date'] as String),
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
      status: DebtStatusX.fromWire(r['status'] as String?),
    );
  }
}
