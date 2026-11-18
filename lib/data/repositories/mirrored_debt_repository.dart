import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/mirrored_debt_payment.dart';
import 'package:sqflite/sqflite.dart';

final mirroredDebtRepositoryProvider = Provider<MirroredDebtRepository>((ref) {
  return _RiverpodMirroredDebtRepository(ref);
});

/// Base class exposing all logic; subclasses provide the db getter.
/// This allows testing without Riverpod by overriding [db].
abstract class MirroredDebtRepository {
  Future<dynamic> get db;

  /// Returns all mirrored debts for [userId] as [Debt] instances (via Debt.mirrored factory).
  Future<List<Debt>> getAllAsDebts(String userId) async {
    final d = await db;
    final rows = await d.query(
      tableMirroredDebts,
      where: 'debtor_user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    ) as List<Map<String, dynamic>>;
    return rows.map((r) {
      final dueDateRaw = r['due_date'] as String?;
      return Debt.mirrored(
        mirroredDebtId: r['id'] as String,
        userId: r['debtor_user_id'] as String,
        creditorEmail: r['creditor_email'] as String,
        name: (r['debtor_name'] as String?) ?? 'Deuda',
        totalAmount: (r['total_amount'] as num).toDouble(),
        dueDate: dueDateRaw != null ? DateTime.tryParse(dueDateRaw) ?? DateTime.now() : DateTime.now(),
        status: r['status'] as String,
        createdAt: r['created_at'] as String?,
      );
    }).toList();
  }

  /// Sums all payment amounts for the given mirrored debt.
  Future<double> getTotalPaidByMirroredId(String mirroredId) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM $tableMirroredDebtPayments WHERE mirrored_debt_id = ?',
      [mirroredId],
    ) as List<Map<String, dynamic>>;
    return (rows.first['t'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns all payments for a mirrored debt ordered by date DESC.
  Future<List<MirroredDebtPayment>> paymentsFor(String mirroredId) async {
    final d = await db;
    final rows = await d.query(
      tableMirroredDebtPayments,
      where: 'mirrored_debt_id = ?',
      whereArgs: [mirroredId],
      orderBy: 'date DESC',
    ) as List<Map<String, dynamic>>;
    return rows.map(MirroredDebtPayment.fromJson).toList();
  }

  /// Blind upsert (server is always authoritative — no pending guard).
  /// Updates in place so the cascade does not drop its local payments.
  Future<void> upsertFromRemote(Map<String, dynamic> m) async {
    final d = await db;
    await upsertRowById(
      d,
      tableMirroredDebts,
      {
        'id': m['id'],
        'receivable_id': m['receivable_id'],
        'debtor_user_id': m['debtor_user_id'],
        'creditor_user_id': m['creditor_user_id'],
        'creditor_email': m['creditor_email'],
        'debtor_name': m['debtor_name'],
        'total_amount': (m['total_amount'] as num).toDouble(),
        'description': m['description'],
        'due_date': m['due_date']?.toString(),
        'status': m['status'],
        'revoked_at': m['revoked_at']?.toString(),
        columnSyncStatus: 'synced',
        columnUpdatedAt: DateTime.now().toIso8601String(),
        'created_at': m['created_at']?.toString(),
      },
      );
  }

  /// Upsert a mirrored payment (blind replace — server authoritative).
  Future<void> upsertPaymentFromRemote(Map<String, dynamic> p) async {
    final d = await db;
    await d.insert(
      tableMirroredDebtPayments,
      {
        'id': p['id'],
        'mirrored_debt_id': p['mirrored_debt_id'],
        'source_payment_id': p['source_payment_id'],
        'amount': (p['amount'] as num).toDouble(),
        'date': p['date']?.toString(),
        columnSyncStatus: 'synced',
        columnUpdatedAt: DateTime.now().toIso8601String(),
        'created_at': p['created_at']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Manual delete — allowed ONLY when status is 'revoked'.
  /// The UI enforces this; the repo re-checks as a safety net.
  Future<void> deleteByMirroredId(String mirroredId) async {
    final d = await db;
    final rows = await d.query(
      tableMirroredDebts,
      where: 'id = ?',
      whereArgs: [mirroredId],
    ) as List<Map<String, dynamic>>;
    if (rows.isEmpty) return;
    if (rows.first['status'] != 'revoked') {
      throw StateError('Cannot delete an active mirrored debt');
    }
    await d.delete(tableMirroredDebtPayments, where: 'mirrored_debt_id = ?', whereArgs: [mirroredId]);
    await d.delete(tableMirroredDebts, where: 'id = ?', whereArgs: [mirroredId]);
  }

  /// Remove local mirrors that are no longer present in the server response.
  /// Called after a pull to clean up server-deleted rows.
  Future<void> pruneAbsent(String userId, Set<String> remoteIds) async {
    final d = await db;
    if (remoteIds.isEmpty) {
      await d.delete(tableMirroredDebts, where: 'debtor_user_id = ?', whereArgs: [userId]);
      return;
    }
    final placeholders = remoteIds.map((_) => '?').join(', ');
    await d.rawDelete(
      'DELETE FROM $tableMirroredDebts WHERE debtor_user_id = ? AND id NOT IN ($placeholders)',
      [userId, ...remoteIds],
    );
  }
}

class _RiverpodMirroredDebtRepository extends MirroredDebtRepository {
  _RiverpodMirroredDebtRepository(this._ref);
  final Ref _ref;

  @override
  Future<dynamic> get db => _ref.read(databaseProvider.future);
}
