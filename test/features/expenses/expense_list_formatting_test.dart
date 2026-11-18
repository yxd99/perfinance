import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expense_list_formatting.dart';

Expense _expense(String id, DateTime date, {double amount = 1000, String? description}) => Expense(
      id: id,
      userId: 'u1',
      amount: amount,
      date: date,
      paymentType: 'payment_method',
      paymentRef: 'm1',
      description: description,
    );

void main() {
  group('expenseRowText', () {
    test('usa la descripción como título', () {
      final t = expenseRowText('Mercado', 'Nequi');
      expect(t.title, 'Mercado');
      expect(t.fromWallet, isFalse);
    });

    test('sin descripción usa el alias de la cuenta', () {
      expect(expenseRowText(null, 'Nequi').title, 'Nequi');
      expect(expenseRowText('   ', 'Nequi').title, 'Nequi');
    });

    test('quita el prefijo [Wallet]: y marca el egreso como de Wallet', () {
      final t = expenseRowText('[Wallet]: Éxito Calle 80', 'Visa');
      expect(t.title, 'Éxito Calle 80');
      expect(t.fromWallet, isTrue);
    });

    test('prefijo [Wallet]: sin comercio cae al alias', () {
      final t = expenseRowText('[Wallet]:', 'Visa');
      expect(t.title, 'Visa');
      expect(t.fromWallet, isTrue);
    });
  });

  group('groupExpensesByDay', () {
    test('agrupa por día local, días más recientes primero, con total por día', () {
      final groups = groupExpensesByDay([
        _expense('a', DateTime(2026, 11, 15, 9), amount: 100),
        _expense('b', DateTime(2026, 11, 17, 8), amount: 200),
        _expense('c', DateTime(2026, 11, 15, 20), amount: 300),
      ]);
      expect(groups.map((g) => g.day), [DateTime(2026, 11, 17), DateTime(2026, 11, 15)]);
      expect(groups.last.expenses.map((e) => e.id), ['a', 'c']);
      expect(groups.last.total, 400);
      expect(groups.first.total, 200);
    });

    test('lista vacía devuelve cero grupos', () {
      expect(groupExpensesByDay(const []), isEmpty);
    });
  });

  group('expenseDayLabel', () {
    final now = DateTime(2026, 11, 17, 14);

    test('hoy y ayer por nombre', () {
      expect(expenseDayLabel(DateTime(2026, 11, 17), now: now), 'Hoy');
      expect(expenseDayLabel(DateTime(2026, 11, 16), now: now), 'Ayer');
    });

    test('mismo año sin año, otro año con año', () {
      expect(expenseDayLabel(DateTime(2026, 11, 15), now: now), '15 nov');
      expect(expenseDayLabel(DateTime(2025, 12, 31), now: now), '31 dic 2025');
    });
  });

  group('expenseEmptyCopy', () {
    test('sin ningún egreso registrado invita a registrar', () {
      final c = expenseEmptyCopy(
        hasAnyExpenses: false,
        filter: ExpenseDateFilterType.today,
        hasPaymentFilter: false,
      );
      expect(c.message, 'No hay egresos registrados');
      expect(c.action, ExpenseEmptyAction.logExpense);
    });

    test('filtro de hoy vacío lo dice y ofrece ver el mes', () {
      final c = expenseEmptyCopy(
        hasAnyExpenses: true,
        filter: ExpenseDateFilterType.today,
        hasPaymentFilter: false,
      );
      expect(c.message, 'Hoy no registraste egresos');
      expect(c.action, ExpenseEmptyAction.showCurrentMonth);
      expect(c.actionLabel, 'Ver este mes');
    });

    test('rango personalizado vacío', () {
      final c = expenseEmptyCopy(
        hasAnyExpenses: true,
        filter: ExpenseDateFilterType.custom,
        hasPaymentFilter: false,
      );
      expect(c.message, 'No hay egresos en este rango');
      expect(c.action, ExpenseEmptyAction.showCurrentMonth);
    });

    test('mes vacío ofrece los últimos 30 días', () {
      final c = expenseEmptyCopy(
        hasAnyExpenses: true,
        filter: ExpenseDateFilterType.currentMonth,
        hasPaymentFilter: false,
      );
      expect(c.message, 'Este mes no registraste egresos');
      expect(c.action, ExpenseEmptyAction.showLast30Days);
    });

    test('filtro de cuentas activo ofrece quitarlo', () {
      final c = expenseEmptyCopy(
        hasAnyExpenses: true,
        filter: ExpenseDateFilterType.thisWeek,
        hasPaymentFilter: true,
      );
      expect(c.message, 'No hay egresos de esas cuentas en este período');
      expect(c.action, ExpenseEmptyAction.clearPaymentFilter);
    });
  });
}
