import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:sqflite/sqflite.dart';

final receivablePaymentRepositoryProvider =
    Provider<ReceivablePaymentRepository>((ref) {
  return ReceivablePaymentRepository(ref);
});

class ReceivablePaymentRepository {
  ReceivablePaymentRepository(this._ref, {dynamic dbOverride})
      : _dbOverride = dbOverride;
  final Ref? _ref;
  final dynamic _dbOverride;

  Future<dynamic> get _db async {
    if (_dbOverride != null) return _dbOverride;
    return _ref!.read(databaseProvider.future);
  }

  // ── queries ────────────────────────────────────────────────────────────────

  Future<List<ReceivablePayment>> getByReceivableId(String receivableId) async {
    final db = await _db;
    final rows = await db.query(
          tableReceivablePayments,
          where: 'receivable_id = ? AND $columnSyncStatus != ?',
          whereArgs: [receivableId, 'pending_delete'],
          orderBy: 'date DESC',
        ) as List<Map<String, dynamic>>;
    return rows.map(_rowToPayment).toList();
  }

  Future<double> getTotalPaid(String receivableId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM $tableReceivablePayments '
      "WHERE receivable_id = ? AND $columnSyncStatus != 'pending_delete'",
      [receivableId],
    ) as List<Map<String, dynamic>>;
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<ReceivablePayment>> getPendingForPush() async {
    final db = await _db;
    final rows = await db.query(
          tableReceivablePayments,
          where: "$columnSyncStatus IN ('pending_insert', 'pending_update', 'pending_delete')",
        ) as List<Map<String, dynamic>>;
    return rows.map(_rowToPayment).toList();
  }

  // ── insert ─────────────────────────────────────────────────────────────────

  Future<void> insert(ReceivablePayment p) async {
    final db = await _db;
    await db.transaction((txn) async {
      final parentRows = await txn.query(
            tableReceivables,
            where: 'id = ?',
            whereArgs: [p.receivableId],
          ) as List<Map<String, dynamic>>;

      if (parentRows.isEmpty) throw StateError('Receivable not found');
      final total = (parentRows.first['total_amount'] as num).toDouble();
      final remaining =
          await _remainingInTxn(txn, p.receivableId, total, excludeId: '');

      if (p.amount > remaining + 0.001) {
        throw StateError(
            'Overpayment: amount ${p.amount} exceeds remaining $remaining');
      }

      final now = DateTime.now().toIso8601String();
      await txn.insert(tableReceivablePayments, {
        'id': p.id,
        'receivable_id': p.receivableId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        'note': p.note,
        columnSyncStatus: 'pending_insert',
        columnUpdatedAt: now,
        'created_at': now,
      });

      await _checkAndAutoSettle(txn, p.receivableId, total, parentRows.first);
    });
  }

  // ── update ─────────────────────────────────────────────────────────────────

  Future<void> update(ReceivablePayment p) async {
    final db = await _db;
    await db.transaction((txn) async {
      final parentRows = await txn.query(
            tableReceivables,
            where: 'id = ?',
            whereArgs: [p.receivableId],
          ) as List<Map<String, dynamic>>;

      if (parentRows.isEmpty) throw StateError('Receivable not found');
      final total = (parentRows.first['total_amount'] as num).toDouble();
      final remaining = await _remainingInTxn(txn, p.receivableId, total,
          excludeId: p.id);

      if (p.amount > remaining + 0.001) {
        throw StateError(
            'Overpayment: amount ${p.amount} exceeds remaining $remaining');
      }

      await txn.update(
        tableReceivablePayments,
        {
          'amount': p.amount,
          'date': p.date.toIso8601String(),
          'note': p.note,
          columnSyncStatus: 'pending_update',
          columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [p.id],
      );

      await _checkAndAutoSettle(txn, p.receivableId, total, parentRows.first);
    });
  }

  // ── delete ─────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    final db = await _db;
    final rows = await db.query(
          tableReceivablePayments,
          where: 'id = ?',
          whereArgs: [id],
        ) as List<Map<String, dynamic>>;
    if (rows.isEmpty) return;
    final payment = rows.first;
    final receivableId = payment['receivable_id'] as String;

    await db.transaction((txn) async {
      if (payment[columnSyncStatus] == 'pending_insert') {
        await txn.delete(
          tableReceivablePayments,
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.update(
          tableReceivablePayments,
          {
            columnSyncStatus: 'pending_delete',
            columnUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      final parentRows = await txn.query(
            tableReceivables,
            where: 'id = ?',
            whereArgs: [receivableId],
          ) as List<Map<String, dynamic>>;

      if (parentRows.isNotEmpty) {
        final total = (parentRows.first['total_amount'] as num).toDouble();
        await _checkAndAutoSettle(txn, receivableId, total, parentRows.first);
      }
    });
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      tableReceivablePayments,
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
    await db.delete(tableReceivablePayments, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertFromRemote(ReceivablePayment p) async {
    final db = await _db;
    final existing = await db.query(
          tableReceivablePayments,
          where: 'id = ?',
          whereArgs: [p.id],
        ) as List<Map<String, dynamic>>;

    if (existing.isNotEmpty &&
        (existing.first[columnSyncStatus] as String?) != 'synced') {
      return; // local wins
    }
    final now = DateTime.now().toIso8601String();
    await db.insert(
      tableReceivablePayments,
      {
        'id': p.id,
        'receivable_id': p.receivableId,
        'amount': p.amount,
        'date': p.date.toIso8601String(),
        'note': p.note,
        columnSyncStatus: 'synced',
        columnUpdatedAt: now,
        'created_at': p.createdAt ?? now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── private helpers ────────────────────────────────────────────────────────

  /// Computes remaining balance INSIDE a transaction, excluding [excludeId]
  /// from the SUM (pass '' for insert, payment.id for update).
  Future<double> _remainingInTxn(
    Transaction txn,
    String receivableId,
    double totalAmount, {
    required String excludeId,
  }) async {
    final rows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0) AS paid
          FROM $tableReceivablePayments
          WHERE receivable_id = ?
            AND id != ?
            AND $columnSyncStatus != 'pending_delete'
          ''',
          [receivableId, excludeId],
        ) as List<Map<String, dynamic>>;
    final paid = (rows.first['paid'] as num?)?.toDouble() ?? 0.0;
    return totalAmount - paid;
  }

  /// Checks the parent's total paid and flips status active↔settled if needed.
  /// ONLY transitions between active and settled — never overrides writtenOff or hidden.
  Future<void> _checkAndAutoSettle(
    Transaction txn,
    String receivableId,
    double totalAmount,
    Map<String, dynamic> parentRow,
  ) async {
    final paidRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(amount), 0) AS paid
          FROM $tableReceivablePayments
          WHERE receivable_id = ?
            AND $columnSyncStatus != 'pending_delete'
          ''',
          [receivableId],
        ) as List<Map<String, dynamic>>;
    final paid = (paidRows.first['paid'] as num?)?.toDouble() ?? 0.0;
    final currentStatus = parentRow['status'] as String?;

    String? newStatus;
    if (paid >= totalAmount - 0.001 && currentStatus == 'active') {
      newStatus = 'settled';
    } else if (paid < totalAmount - 0.001 && currentStatus == 'settled') {
      newStatus = 'active';
    }
    // writtenOff and hidden are never touched

    if (newStatus != null) {
      await txn.update(
        tableReceivables,
        {
          'status': newStatus,
          columnSyncStatus: 'pending_update',
          columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [receivableId],
      );
    }
  }

  // ── row mapper ─────────────────────────────────────────────────────────────

  static ReceivablePayment _rowToPayment(Map<String, dynamic> r) {
    return ReceivablePayment(
      id: r['id'] as String,
      receivableId: r['receivable_id'] as String,
      amount: (r['amount'] as num).toDouble(),
      date: DateTime.parse(r['date'] as String),
      note: r['note'] as String?,
      syncStatus: r[columnSyncStatus] as String? ?? 'synced',
      updatedAt: r[columnUpdatedAt] as String?,
      createdAt: r['created_at'] as String?,
    );
  }
}
