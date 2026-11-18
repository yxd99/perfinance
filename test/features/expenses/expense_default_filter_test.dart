import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/expenses/expense_date_filter.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';

void main() {
  test('Egresos abre en el mes actual', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(selectedExpenseDateFilterProvider).type, ExpenseDateFilterType.currentMonth);
  });
}
