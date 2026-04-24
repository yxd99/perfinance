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
    final rangeStartDay = DateTime(range.start.year, range.start.month, range.start.day);
    final rangeEndDay = DateTime(range.end.year, range.end.month, range.end.day);
    final windowEndLocal =
        DateTime(rangeEndDay.year, rangeEndDay.month, rangeEndDay.day, 23, 59, 59, 999);
    return ExpenseExportWindow(
      rangeLabel: filter.label,
      windowStartIso: rangeStartDay.toUtc().toIso8601String(),
      windowEndIso: windowEndLocal.toUtc().toIso8601String(),
      timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }
}
