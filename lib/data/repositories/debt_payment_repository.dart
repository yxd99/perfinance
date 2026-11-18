import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:sqflite/sqflite.dart';

final debtPaymentRepositoryProvider = Provider<DebtPaymentRepository>((ref) {
  return DebtPaymentRepository(ref);
});

class DebtPaymentRepository {
  DebtPaymentRepository(this._ref, {Database? dbOverride}) : _dbOverride = dbOverride;
  final Ref? _ref;
  final Database? _dbOverride;

  Future<Database> get _db async {
    if (_dbOverride != null) return _dbOverride;
    return _ref!.read(databaseProvider.future);
  }

  Future<List<DebtPayment>> getByDebtId(String debtId) async {
    final db = await _db;
    final rows = await db.query(
      tableDebtPayments,
      where: 'debt_id = ? AND $columnSyncStatus != ?',
      whereArgs: [debtId, 'pending_delete'],
      orderBy: 'date DESC',
    );
    return rows.map(_rowToPayment).toList();
  }

  Future<double> getTotalPaidByDebtId(String debtId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableDebtPayments WHERE debt_id = ? AND $columnSyncStatus != ?',
      [debtId, 'pending_delete'],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<DebtPayment>> getPendingForPush() async {
    final db = await _db;
    final rows = await db.query(
      tableDebtPayments,
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    return rows.map(_rowToPayment).toList();
  }

  Future<void> insert(DebtPayment p) async {
    final db = await _db;
    final debtRow = await db.query(tableDebts, where: 'id = ?', whereArgs: [p.debtId]);
    if (debtRow.isNotEmpty) {
      final s = debtRow.first['status'] as String?;
      // Una deuda oculta sigue abierta: se le pueden registrar pagos.
      if (s == 'paid') {
        throw StateError('Cannot insert payment for a $s debt');
      }
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableDebtPayments,
      {
        'id': p.id,
        'debt_id': p.debtId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      },
    );
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableDebtPayments,
      {columnSyncStatus: 'synced', columnUpdatedAt: DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsertFromRemote(DebtPayment p) async {
    final db = await _db;
    final existing = await db.query(tableDebtPayments, where: 'id = ?', whereArgs: [p.id]);
    if (existing.isNotEmpty && (existing.first[columnSyncStatus] as String?) != 'synced') {
      return;
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableDebtPayments,
      {
        'id': p.id,
        'debt_id': p.debtId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        columnSyncStatus: 'synced',
        columnUpdatedAt: p.updatedAt ?? now,
        'created_at': p.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marca el pago como pendiente de borrado (o lo borra si era pending_insert). Para sincronizar después.
  Future<void> delete(String id) async {
    final db = await _db;
    final rows = await db.query(tableDebtPayments, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    if (rows.first[columnSyncStatus] == 'pending_insert') {
      await db.delete(tableDebtPayments, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableDebtPayments,
        {columnSyncStatus: 'pending_delete', columnUpdatedAt: DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Borra el registro local (usar tras sincronizar un pending_delete).
  Future<void> deleteLocal(String id) async {
    final db = await _db;
    await db.delete(tableDebtPayments, where: 'id = ?', whereArgs: [id]);
  }

  static DebtPayment _rowToPayment(Map<String, dynamic> r) {
    return DebtPayment(
      id: r['id'] as String,
      debtId: r['debt_id'] as String,
      amount: (r['amount'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
