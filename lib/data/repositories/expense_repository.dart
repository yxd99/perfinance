import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:sqflite/sqflite.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref);
});

class ExpenseRepository {
  ExpenseRepository(this._ref, {dynamic dbOverride}) : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<Database> get _db async {
    if (_dbOverride != null) return _dbOverride as Database;
    return _ref!.read(databaseProvider.future);
  }

  Future<List<Expense>> getAll(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableExpenses,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'pending_delete'],
      orderBy: 'date DESC',
    );
    return rows.map(_rowToExpense).toList();
  }

  Future<List<Expense>> getPendingForPush(String userId) async {
    final db = await _db;
    final rows = await db.query(
      tableExpenses,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, 'synced'],
    );
    return rows.map(_rowToExpense).toList();
  }

  Future<void> insert(Expense e) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableExpenses,
      {
        'id': e.id,
        'user_id': e.userId,
        'amount': e.amount,
        'date': e.date.toIso8601String(),
        'payment_type': e.paymentType,
        'payment_ref': e.paymentRef,
        'description': e.description,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> update(Expense e) async {
    final db = await _db;
    await db.update(
      tableExpenses,
      {
        'amount': e.amount,
        'date': e.date.toIso8601String(),
        'payment_type': e.paymentType,
        'payment_ref': e.paymentRef,
        'description': e.description,
        columnSyncStatus: 'pending_update',
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [e.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    final row = await db.query(tableExpenses, where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) return;
    if (row.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tableExpenses, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableExpenses,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableExpenses,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra el registro local (usar tras sincronizar un pending_delete).
  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableExpenses, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(Expense e) async {
    final db = await _db;
    final existing = await db.query(tableExpenses, where: 'id = ?', whereArgs: [e.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableExpenses,
      {
        'id': e.id,
        'user_id': e.userId,
        'amount': e.amount,
        'date': e.date.toIso8601String(),
        'payment_type': e.paymentType,
        'payment_ref': e.paymentRef,
        'description': e.description,
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Expense _rowToExpense(Map<String, dynamic> r) {
    return Expense(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      amount: (r['amount'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      paymentType: r['payment_type'] as String,
      paymentRef: r['payment_ref'] as String,
      description: r['description'] as String?,
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
