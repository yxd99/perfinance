import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';

/// Prefijo que pone la edge function `log-wallet-expense` en la descripción.
const String kWalletPrefix = '[Wallet]:';

const List<String> _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Título de una fila de egreso y si vino de Apple Wallet.
class ExpenseRowText {
  const ExpenseRowText({required this.title, required this.fromWallet});
  final String title;
  final bool fromWallet;
}

/// La descripción es el título; sin descripción, el alias de la cuenta.
/// Los egresos de Wallet muestran el comercio sin el prefijo técnico.
ExpenseRowText expenseRowText(String? description, String accountAlias) {
  final raw = description?.trim() ?? '';
  final fromWallet = raw.startsWith(kWalletPrefix);
  final text = fromWallet ? raw.substring(kWalletPrefix.length).trim() : raw;
  return ExpenseRowText(title: text.isEmpty ? accountAlias : text, fromWallet: fromWallet);
}

/// Egresos de un mismo día (hora local).
class ExpenseDayGroup {
  ExpenseDayGroup(this.day, this.expenses);
  final DateTime day;
  final List<Expense> expenses;

  double get total => expenses.fold<double>(0, (s, e) => s + e.amount);
}

/// Agrupa por día local, días más recientes primero; dentro del día se
/// conserva el orden recibido.
List<ExpenseDayGroup> groupExpensesByDay(List<Expense> expenses) {
  final byDay = <DateTime, List<Expense>>{};
  for (final e in expenses) {
    final d = e.date.toLocal();
    byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(e);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final d in days) ExpenseDayGroup(d, byDay[d]!)];
}

/// «15 nov», o «15 nov 2025» si no es del año de [now].
String expenseShortDate(DateTime day, {required DateTime now}) {
  final base = '${day.day} ${_months[day.month - 1]}';
  return day.year == now.year ? base : '$base ${day.year}';
}

/// Encabezado de día: «Hoy», «Ayer» o la fecha corta.
String expenseDayLabel(DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return 'Hoy';
  if (d == DateTime(today.year, today.month, today.day - 1)) return 'Ayer';
  return expenseShortDate(d, now: now);
}

enum ExpenseEmptyAction { logExpense, showCurrentMonth, showLast30Days, clearPaymentFilter }

/// Mensaje honesto cuando la lista sale vacía y qué ofrecer para salir de ahí.
class ExpenseEmptyCopy {
  const ExpenseEmptyCopy(this.message, this.action, this.actionLabel);
  final String message;
  final ExpenseEmptyAction action;
  final String actionLabel;
}

ExpenseEmptyCopy expenseEmptyCopy({
  required bool hasAnyExpenses,
  required ExpenseDateFilterType filter,
  required bool hasPaymentFilter,
}) {
  const log = ExpenseEmptyAction.logExpense;
  const month = ExpenseEmptyAction.showCurrentMonth;
  if (!hasAnyExpenses) return const ExpenseEmptyCopy('No hay egresos registrados', log, 'Registrar egreso');
  if (hasPaymentFilter) {
    return const ExpenseEmptyCopy(
      'No hay egresos de esas cuentas en este período',
      ExpenseEmptyAction.clearPaymentFilter,
      'Ver todas las cuentas',
    );
  }
  switch (filter) {
    case ExpenseDateFilterType.today:
      return const ExpenseEmptyCopy('Hoy no registraste egresos', month, 'Ver este mes');
    case ExpenseDateFilterType.yesterday:
      return const ExpenseEmptyCopy('Ayer no registraste egresos', month, 'Ver este mes');
    case ExpenseDateFilterType.thisWeek:
      return const ExpenseEmptyCopy('Esta semana no registraste egresos', month, 'Ver este mes');
    case ExpenseDateFilterType.currentMonth:
      return const ExpenseEmptyCopy(
        'Este mes no registraste egresos',
        ExpenseEmptyAction.showLast30Days,
        'Ver últimos 30 días',
      );
    case ExpenseDateFilterType.last30Days:
      return const ExpenseEmptyCopy('No registraste egresos en los últimos 30 días', log, 'Registrar egreso');
    case ExpenseDateFilterType.custom:
      return const ExpenseEmptyCopy('No hay egresos en este rango', month, 'Ver este mes');
  }
}
