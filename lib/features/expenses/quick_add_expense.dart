import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/features/expenses/expense_form_screen.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';

/// Registro rápido de un egreso desde el «+» de la barra inferior.
///
/// Es el único punto de entrada que usa el shell. El formulario se presenta
/// como hoja de iOS (tarea corta y descartable): crece con el contenido y con
/// el teclado, y si no entra hace scroll por dentro.
Future<void> showQuickAddExpense(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ExpenseFormScreen(asSheet: true),
  );
  if (context.mounted) ref.invalidate(expensesListProvider);
}
