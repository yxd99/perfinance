import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';

/// Registro rápido de un egreso desde el «+» de la barra inferior.
///
/// Es el único punto de entrada que usa el shell; cómo se presenta el
/// formulario (hoja o pantalla) es decisión de esta feature.
Future<void> showQuickAddExpense(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const ExpenseFormScreen(),
    ),
  );
  ref.invalidate(expensesListProvider);
}
