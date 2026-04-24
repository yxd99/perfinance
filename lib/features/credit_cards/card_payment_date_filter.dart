import 'package:flutter/material.dart';

enum CardPaymentDateFilterType {
  today,
  yesterday,
  thisWeek,
  last30Days,
  currentMonth,
  custom,
}

class CardPaymentDateFilter {
  const CardPaymentDateFilter._(this.type, [this.range]);

  final CardPaymentDateFilterType type;
  final DateTimeRange? range;

  static const CardPaymentDateFilter today = CardPaymentDateFilter._(CardPaymentDateFilterType.today);
  static const CardPaymentDateFilter yesterday = CardPaymentDateFilter._(CardPaymentDateFilterType.yesterday);
  static const CardPaymentDateFilter thisWeek = CardPaymentDateFilter._(CardPaymentDateFilterType.thisWeek);
  static const CardPaymentDateFilter last30Days = CardPaymentDateFilter._(CardPaymentDateFilterType.last30Days);
  static const CardPaymentDateFilter currentMonth = CardPaymentDateFilter._(CardPaymentDateFilterType.currentMonth);

  static CardPaymentDateFilter custom(DateTimeRange range) =>
      CardPaymentDateFilter._(CardPaymentDateFilterType.custom, range);

  DateTimeRange get rangeOrNow {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (type) {
      case CardPaymentDateFilterType.today:
        return DateTimeRange(start: startOfToday, end: now);
      case CardPaymentDateFilterType.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: yesterday,
          end: yesterday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case CardPaymentDateFilterType.thisWeek:
        final weekday = now.weekday;
        final startWeek = startOfToday.subtract(Duration(days: weekday - 1));
        return DateTimeRange(start: startWeek, end: now);
      case CardPaymentDateFilterType.last30Days:
        return DateTimeRange(start: startOfToday.subtract(const Duration(days: 29)), end: now);
      case CardPaymentDateFilterType.currentMonth:
        final startMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: startMonth, end: now);
      case CardPaymentDateFilterType.custom:
        final end = range!.end;
        final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        return DateTimeRange(start: range!.start, end: endOfDay);
    }
  }

  String get label {
    switch (type) {
      case CardPaymentDateFilterType.today:
        return 'Hoy';
      case CardPaymentDateFilterType.yesterday:
        return 'Ayer';
      case CardPaymentDateFilterType.thisWeek:
        return 'Esta semana';
      case CardPaymentDateFilterType.last30Days:
        return 'Últimos 30 días';
      case CardPaymentDateFilterType.currentMonth:
        return 'Mes actual';
      case CardPaymentDateFilterType.custom:
        return 'Rango personalizado';
    }
  }
}

