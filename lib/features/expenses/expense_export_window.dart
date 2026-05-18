import 'package:perfinance/features/expenses/expense_date_filter.dart';

/// Ventana UTC enviada a la Edge Function; coincide con el criterio de días locales
/// de [filteredExpensesListProvider].
class ExpenseExportWindow {
  ExpenseExportWindow({
    required this.rangeLabel,
    required this.windowStartIso,
    required this.windowEndIso,
    required this.timezoneOffsetMinutes,
  });

  final String rangeLabel;
  final String windowStartIso;
  final String windowEndIso;
  final int timezoneOffsetMinutes;

  factory ExpenseExportWindow.fromFilter(ExpenseDateFilter filter) {
    final range = filter.rangeOrNow;
    final s = range.start;
    final e = range.end;
    // Expenses are stored in Supabase as UTC midnight (Flutter serializes DateTime without
    // timezone → Postgres interprets as UTC). Use UTC midnight directly so the query bounds
    // match the stored values, regardless of the client's local offset.
    return ExpenseExportWindow(
      rangeLabel: filter.label,
      windowStartIso: DateTime.utc(s.year, s.month, s.day).toIso8601String(),
      windowEndIso: DateTime.utc(e.year, e.month, e.day, 23, 59, 59, 999).toIso8601String(),
      timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }
}
