import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expense_export_window.dart';

void main() {
  test('ExpenseExportWindow.fromFilter incluye rango e intervalo de fechas', () {
    final w = ExpenseExportWindow.fromFilter(ExpenseDateFilter.today);
    expect(w.rangeLabel, 'Hoy');
    final start = DateTime.parse(w.windowStartIso);
    final end = DateTime.parse(w.windowEndIso);
    expect(end.isAfter(start) || end.isAtSameMomentAs(start), isTrue);
    expect(w.timezoneOffsetMinutes, DateTime.now().timeZoneOffset.inMinutes);
  });
}
