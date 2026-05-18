import 'package:flutter/material.dart';
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

  group('windowStartIso / windowEndIso son UTC midnight sin offset local', () {
    // Los gastos en Supabase se guardan como YYYY-MM-DDT00:00:00Z (UTC midnight).
    // Los bounds deben coincidir con esa representación, sin importar el timezone del cliente.

    test('custom range — start es UTC midnight del día seleccionado', () {
      final filter = ExpenseDateFilter.custom(
        DateTimeRange(
          start: DateTime(2026, 4, 15),
          end: DateTime(2026, 5, 18),
        ),
      );
      final w = ExpenseExportWindow.fromFilter(filter);
      expect(w.windowStartIso, '2026-04-15T00:00:00.000Z');
    });

    test('custom range — end es UTC 23:59:59.999 del último día', () {
      final filter = ExpenseDateFilter.custom(
        DateTimeRange(
          start: DateTime(2026, 4, 15),
          end: DateTime(2026, 5, 18),
        ),
      );
      final w = ExpenseExportWindow.fromFilter(filter);
      expect(w.windowEndIso, '2026-05-18T23:59:59.999Z');
    });

    test('rango de un solo día — start y end cubren ese día completo en UTC', () {
      final filter = ExpenseDateFilter.custom(
        DateTimeRange(
          start: DateTime(2026, 5, 1),
          end: DateTime(2026, 5, 1),
        ),
      );
      final w = ExpenseExportWindow.fromFilter(filter);
      expect(w.windowStartIso, '2026-05-01T00:00:00.000Z');
      expect(w.windowEndIso, '2026-05-01T23:59:59.999Z');
    });

    test('rango cruzando año — bounds correctos sin drift de offset', () {
      final filter = ExpenseDateFilter.custom(
        DateTimeRange(
          start: DateTime(2025, 12, 31),
          end: DateTime(2026, 1, 1),
        ),
      );
      final w = ExpenseExportWindow.fromFilter(filter);
      expect(w.windowStartIso, '2025-12-31T00:00:00.000Z');
      expect(w.windowEndIso, '2026-01-01T23:59:59.999Z');
    });

    test('timezoneOffsetMinutes se mantiene para display del Excel', () {
      final filter = ExpenseDateFilter.custom(
        DateTimeRange(
          start: DateTime(2026, 4, 15),
          end: DateTime(2026, 5, 18),
        ),
      );
      final w = ExpenseExportWindow.fromFilter(filter);
      expect(w.timezoneOffsetMinutes, DateTime.now().timeZoneOffset.inMinutes);
    });
  });
}
