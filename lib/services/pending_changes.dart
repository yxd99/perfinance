import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// Tablas cuyos cambios locales se suben a Supabase (las espejo son solo de bajada).
const List<String> pushedTables = [
  tableCreditCards,
  tablePaymentMethods,
  tableExpenses,
  tableCardPayments,
  tableMinPaymentConfigs,
  tableDebts,
  tableDebtPayments,
  tableAutomaticPayments,
  tableReceivables,
  tableReceivablePayments,
];

/// Cantidad de filas locales que todavía no llegaron a Supabase.
Future<int> countPendingChanges(DatabaseExecutor db) async {
  var total = 0;
  for (final table in pushedTables) {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $table WHERE $columnSyncStatus != ?',
      ['synced'],
    );
    total += (rows.first['n'] as int?) ?? 0;
  }
  return total;
}
