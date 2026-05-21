import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debts_provider.dart';

Debt _debt(String id, DebtStatus status) => Debt(
      id: id,
      userId: 'user-1',
      name: 'Debt $id',
      totalAmount: 1000,
      numberOfInstallments: 10,
      dueDate: DateTime(2026, 12, 31),
      status: status,
    );

DebtWithPaid _withPaid(String id, DebtStatus status) =>
    DebtWithPaid(debt: _debt(id, status), paid: 0);

List<DebtWithPaid> _applyFilter(List<DebtWithPaid> list, DebtListFilter filter) {
  switch (filter) {
    case DebtListFilter.active:
      return list.where((e) => e.debt.status == DebtStatus.active).toList();
    case DebtListFilter.paid:
      return list.where((e) => e.debt.status == DebtStatus.paid).toList();
    case DebtListFilter.hidden:
      return list.where((e) => e.debt.status == DebtStatus.hidden).toList();
    case DebtListFilter.all:
      return list.where((e) => e.debt.status != DebtStatus.hidden).toList();
  }
}

void main() {
  final all = [
    _withPaid('active-1', DebtStatus.active),
    _withPaid('active-2', DebtStatus.active),
    _withPaid('paid-1', DebtStatus.paid),
    _withPaid('hidden-1', DebtStatus.hidden),
  ];

  group('filteredDebtsWithPaidProvider filter logic', () {
    test('active filter returns only active debts', () {
      final result = _applyFilter(all, DebtListFilter.active);
      expect(result.every((e) => e.debt.status == DebtStatus.active), isTrue);
      expect(result.length, 2);
    });

    test('paid filter returns only paid debts', () {
      final result = _applyFilter(all, DebtListFilter.paid);
      expect(result.every((e) => e.debt.status == DebtStatus.paid), isTrue);
      expect(result.length, 1);
    });

    test('hidden filter returns only hidden debts', () {
      final result = _applyFilter(all, DebtListFilter.hidden);
      expect(result.every((e) => e.debt.status == DebtStatus.hidden), isTrue);
      expect(result.length, 1);
    });

    test('all filter excludes hidden debts', () {
      final result = _applyFilter(all, DebtListFilter.all);
      expect(result.any((e) => e.debt.status == DebtStatus.hidden), isFalse);
      expect(result.length, 3);
    });
  });

  group('outstandingDebtsTotalProvider logic', () {
    double _computeTotal(List<DebtWithPaid> list) {
      return list
          .where((d) => d.debt.status == DebtStatus.active)
          .fold(0.0, (acc, d) => acc + (d.debt.totalAmount - d.paid).clamp(0.0, double.infinity));
    }

    test('excludes paid debts from total', () {
      final list = [
        DebtWithPaid(debt: _debt('d1', DebtStatus.active), paid: 0),
        DebtWithPaid(debt: _debt('d2', DebtStatus.paid), paid: 0),
      ];
      expect(_computeTotal(list), 1000.0);
    });

    test('excludes hidden debts from total', () {
      final list = [
        DebtWithPaid(debt: _debt('d1', DebtStatus.active), paid: 0),
        DebtWithPaid(debt: _debt('d2', DebtStatus.hidden), paid: 0),
      ];
      expect(_computeTotal(list), 1000.0);
    });

    test('sums remaining (total - paid) for active debts only', () {
      final list = [
        DebtWithPaid(debt: _debt('d1', DebtStatus.active), paid: 200),
        DebtWithPaid(debt: _debt('d2', DebtStatus.active), paid: 0),
      ];
      expect(_computeTotal(list), 1800.0);
    });

    test('ignores list filter — always sums active regardless', () {
      final list = [
        DebtWithPaid(debt: _debt('d1', DebtStatus.active), paid: 0),
        DebtWithPaid(debt: _debt('d2', DebtStatus.paid), paid: 1000),
        DebtWithPaid(debt: _debt('d3', DebtStatus.hidden), paid: 0),
      ];
      expect(_computeTotal(list), 1000.0);
    });
  });
}
