import 'package:flutter/material.dart';

/// Filtro de rango de fechas para egresos.
enum ExpenseDateFilterType {
  today,
  yesterday,
  thisWeek,
  last15Days,
  currentMonth,
  custom,
}

class ExpenseDateFilter {
  const ExpenseDateFilter._(this.type, [this.range]);

  final ExpenseDateFilterType type;
  final DateTimeRange? range;

  static const ExpenseDateFilter today = ExpenseDateFilter._(ExpenseDateFilterType.today);
  static const ExpenseDateFilter yesterday = ExpenseDateFilter._(ExpenseDateFilterType.yesterday);
  static const ExpenseDateFilter thisWeek = ExpenseDateFilter._(ExpenseDateFilterType.thisWeek);
  static const ExpenseDateFilter last15Days = ExpenseDateFilter._(ExpenseDateFilterType.last15Days);
  static const ExpenseDateFilter currentMonth = ExpenseDateFilter._(ExpenseDateFilterType.currentMonth);

  static ExpenseDateFilter custom(DateTimeRange range) =>
      ExpenseDateFilter._(ExpenseDateFilterType.custom, range);

  DateTimeRange get rangeOrNow {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (type) {
      case ExpenseDateFilterType.today:
        return DateTimeRange(start: startOfToday, end: now);
      case ExpenseDateFilterType.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return DateTimeRange(start: yesterday, end: yesterday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
      case ExpenseDateFilterType.thisWeek:
        final weekday = now.weekday;
        final startWeek = startOfToday.subtract(Duration(days: weekday - 1));
        return DateTimeRange(start: startWeek, end: now);
      case ExpenseDateFilterType.last15Days:
        return DateTimeRange(start: startOfToday.subtract(const Duration(days: 14)), end: now);
      case ExpenseDateFilterType.currentMonth:
        final startMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: startMonth, end: now);
      case ExpenseDateFilterType.custom:
        // Incluir el día final completo (hasta 23:59:59.999).
        final end = range!.end;
        final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        return DateTimeRange(start: range!.start, end: endOfDay);
    }
  }

  String get label {
    switch (type) {
      case ExpenseDateFilterType.today:
        return 'Hoy';
      case ExpenseDateFilterType.yesterday:
        return 'Ayer';
      case ExpenseDateFilterType.thisWeek:
        return 'Esta semana';
      case ExpenseDateFilterType.last15Days:
        return 'Últimos 15 días';
      case ExpenseDateFilterType.currentMonth:
        return 'Mes actual';
      case ExpenseDateFilterType.custom:
        return 'Rango personalizado';
    }
  }
}
