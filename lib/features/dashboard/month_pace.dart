import 'package:perfinance/data/models/expense.dart';

/// Lógica pura del primer viewport del Mes: cuánto se gastó, contra qué se compara
/// y cómo se dice. Sin Flutter ni Riverpod para poder testearla sola.

const List<String> _monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

/// Nombre del mes en español con mayúscula inicial (1 = enero).
String monthNameEs(int month) => _monthNames[month - 1];

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

/// Gasto de una cuenta (tarjeta o medio de pago) en el mes.
class AccountSpend {
  const AccountSpend({
    required this.paymentType,
    required this.paymentRef,
    required this.total,
    required this.count,
  });

  final String paymentType;
  final String paymentRef;
  final double total;
  final int count;

  bool get isCreditCard => paymentType == 'credit_card';
}

/// Resumen del gasto de un mes contra el mes anterior.
class MonthSpend {
  const MonthSpend({
    required this.month,
    required this.total,
    required this.count,
    required this.toSameDay,
    required this.lastMonthTotal,
    required this.lastMonthToSameDay,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.isInProgress,
    required this.byAccount,
  });

  /// Primer día del mes resumido.
  final DateTime month;

  /// Todos los egresos con fecha en el mes.
  final double total;
  final int count;

  /// Egresos del mes hasta [dayOfMonth] inclusive.
  final double toSameDay;

  /// Todo el mes anterior.
  final double lastMonthTotal;

  /// Mes anterior hasta el mismo día (recortado a su último día).
  final double lastMonthToSameDay;

  /// Día transcurrido: hoy si es el mes en curso, el último si ya cerró.
  final int dayOfMonth;
  final int daysInMonth;

  /// True si es el mes en curso y todavía no terminó.
  final bool isInProgress;

  /// Cuentas con egresos en el mes, de mayor a menor gasto.
  final List<AccountSpend> byAccount;
}

/// Calcula el gasto del mes de [month] con todos los egresos locales.
MonthSpend computeMonthSpend(List<Expense> expenses, DateTime month, DateTime today) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final prevStart = DateTime(month.year, month.month - 1, 1);
  final daysInMonth = _daysIn(month.year, month.month);
  final daysInPrev = _daysIn(prevStart.year, prevStart.month);

  final isCurrent = today.year == month.year && today.month == month.month;
  final isFuture = start.isAfter(today);
  final dayOfMonth = isCurrent ? today.day : (isFuture ? 0 : daysInMonth);
  final isInProgress = isCurrent && today.day < daysInMonth;

  final sameDayEnd = DateTime(month.year, month.month, dayOfMonth + 1);
  final prevDay = dayOfMonth > daysInPrev ? daysInPrev : dayOfMonth;
  final prevSameDayEnd = DateTime(prevStart.year, prevStart.month, prevDay + 1);

  var total = 0.0;
  var count = 0;
  var toSameDay = 0.0;
  var lastTotal = 0.0;
  var lastToSameDay = 0.0;
  final totals = <String, double>{};
  final counts = <String, int>{};
  final types = <String, String>{};

  // «Gastado» es hasta ahora: un egreso con fecha futura no cuenta todavía,
  // igual que en Egresos con el filtro «Mes».
  final spentEnd = end.isAfter(today) ? today : end;
  for (final e in expenses) {
    final d = e.date;
    if (!d.isBefore(start) && !d.isAfter(spentEnd) && d.isBefore(end)) {
      total += e.amount;
      count++;
      if (d.isBefore(sameDayEnd)) toSameDay += e.amount;
      final key = '${e.paymentType}|${e.paymentRef}';
      totals[key] = (totals[key] ?? 0) + e.amount;
      counts[key] = (counts[key] ?? 0) + 1;
      types[key] = e.paymentType;
    } else if (!d.isBefore(prevStart) && d.isBefore(start)) {
      lastTotal += e.amount;
      if (d.isBefore(prevSameDayEnd)) lastToSameDay += e.amount;
    }
  }

  final byAccount = totals.entries.map((entry) {
    final type = types[entry.key]!;
    return AccountSpend(
      paymentType: type,
      paymentRef: entry.key.substring(type.length + 1),
      total: entry.value,
      count: counts[entry.key]!,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return MonthSpend(
    month: start,
    total: total,
    count: count,
    toSameDay: toSameDay,
    lastMonthTotal: lastTotal,
    lastMonthToSameDay: lastToSameDay,
    dayOfMonth: dayOfMonth,
    daysInMonth: daysInMonth,
    isInProgress: isInProgress,
    byAccount: byAccount,
  );
}

/// Relleno del anillo: lo gastado este mes sobre todo el mes anterior, en [0, 1].
/// Sin mes anterior no hay escala y el anillo queda vacío.
double ringFraction(MonthSpend s) {
  if (s.lastMonthTotal <= 0) return 0;
  final f = s.total / s.lastMonthTotal;
  return f > 1 ? 1 : (f < 0 ? 0 : f);
}

/// Frase de ritmo bajo el monto. En el mes en curso compara contra el mes anterior
/// hasta el mismo día; en un mes cerrado, totales contra totales.
String paceSentence(MonthSpend s) {
  final prev = DateTime(s.month.year, s.month.month - 1, 1);
  final prevName = monthNameEs(prev.month).toLowerCase();

  String compare(double current, double base, String suffix) {
    final pct = ((current - base) / base * 100).round();
    if (pct == 0) return 'Igual que $suffix';
    return pct > 0 ? '$pct% más que $suffix' : '${-pct}% menos que $suffix';
  }

  if (s.isInProgress) {
    if (s.lastMonthToSameDay > 0) {
      return compare(s.toSameDay, s.lastMonthToSameDay, 'a esta altura de $prevName');
    }
    if (s.lastMonthTotal > 0) {
      final pct = (s.total / s.lastMonthTotal * 100).round();
      return '$pct% de lo que gastaste en $prevName';
    }
    return 'Sin egresos en $prevName para comparar';
  }
  if (s.lastMonthTotal > 0) return compare(s.total, s.lastMonthTotal, 'en $prevName');
  return 'Sin egresos en $prevName para comparar';
}

/// Estado del próximo corte de una tarjeta si cae dentro de una semana; si no, null.
String? cutOffStatus(int cutOffDay, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  int clamp(int y, int m) {
    final last = _daysIn(y, m);
    return cutOffDay > last ? last : (cutOffDay < 1 ? 1 : cutOffDay);
  }

  var next = DateTime(day.year, day.month, clamp(day.year, day.month));
  if (next.isBefore(day)) {
    final nm = DateTime(day.year, day.month + 1, 1);
    next = DateTime(nm.year, nm.month, clamp(nm.year, nm.month));
  }
  final days = next.difference(day).inDays;
  if (days > 7) return null;
  if (days == 0) return 'Corte hoy';
  if (days == 1) return 'Corte mañana';
  return 'Corte en $days días';
}
