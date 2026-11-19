import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debts_provider.dart';

/// Mensaje honesto cuando la lista de deudas queda vacía.
String debtsEmptyMessage(DebtListFilter filter, String query) {
  final q = query.trim();
  if (q.isNotEmpty) return 'Ninguna deuda coincide con «$q».';
  switch (filter) {
    case DebtListFilter.active:
      return 'No tienes deudas activas.';
    case DebtListFilter.paid:
      return 'Todavía no pagaste ninguna deuda.';
    case DebtListFilter.hidden:
      return 'No tienes deudas ocultas.';
    case DebtListFilter.all:
      return 'Todavía no registraste deudas.';
  }
}

/// Lo que falta por pagar; nunca negativo.
double debtRemaining(DebtWithPaid item) => (item.debt.totalAmount - item.paid).clamp(0.0, double.infinity).toDouble();

/// Vencida: todavía se debe algo y la fecha máxima de pago ya pasó (el mismo día
/// no cuenta). Pagadas, ocultas y recibidas canceladas nunca lo están.
bool isDebtOverdue(DebtWithPaid item, DateTime today) {
  final debt = item.debt;
  final counts = debt.isMirrored ? !debt.isRevoked : debt.status == DebtStatus.active;
  if (!counts || debtRemaining(item) <= 0) return false;
  final due = DateTime(debt.dueDate.year, debt.dueDate.month, debt.dueDate.day);
  return due.isBefore(DateTime(today.year, today.month, today.day));
}

/// Línea de estado bajo el nombre de la deuda en la lista. Con [today], una deuda
/// vencida lo dice en palabras («venció»), no solo con el color del monto.
String debtStatusLine(DebtWithPaid item, {required bool hideValues, DateTime? today}) {
  final debt = item.debt;
  final due = formatDisplayDate(debt.dueDate);
  final overdue = today != null && isDebtOverdue(item, today);
  if (debt.isMirrored) {
    final by = 'Registrada por ${debt.creditorEmail}';
    return overdue ? '$by · venció $due' : by;
  }
  switch (debt.status) {
    case DebtStatus.paid:
      return 'Total \$${formatCurrencyDisplay(debt.totalAmount, hideValues)}';
    case DebtStatus.hidden:
      return 'Oculta · vence $due';
    case DebtStatus.active:
      final n = debt.numberOfInstallments;
      if (n <= 0) return overdue ? 'Venció $due' : 'Vence $due';
      final per = debt.amountPerInstallment;
      final done = per > 0 ? (item.paid / per).floor().clamp(0, n) : 0;
      return '$done de $n cuotas · ${overdue ? 'venció' : 'vence'} $due';
  }
}
