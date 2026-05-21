import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debts_provider.dart';

Debt _debt({DebtStatus status = DebtStatus.active, double totalAmount = 1000}) {
  return Debt(
    id: 'debt-1',
    userId: 'user-1',
    name: 'Test',
    totalAmount: totalAmount,
    numberOfInstallments: 10,
    dueDate: DateTime(2026, 12, 31),
    status: status,
  );
}

void main() {
  group('DebtWithPaid.isPaid', () {
    test('is true when debt.status == DebtStatus.paid regardless of payments', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.paid), paid: 0);
      expect(d.isPaid, isTrue);
    });

    test('is false when debt.status == DebtStatus.active regardless of payment sum', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.active, totalAmount: 100), paid: 100);
      expect(d.isPaid, isFalse);
    });
  });

  group('DebtWithPaid.isHidden', () {
    test('is true when debt.status == DebtStatus.hidden', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.hidden), paid: 0);
      expect(d.isHidden, isTrue);
    });

    test('is false when debt.status is not hidden', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.active), paid: 0);
      expect(d.isHidden, isFalse);
    });
  });

  group('DebtWithPaid.badgeKind', () {
    test('is DebtBadgeKind.paid when status == paid', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.paid), paid: 0);
      expect(d.badgeKind, DebtBadgeKind.paid);
    });

    test('is DebtBadgeKind.hidden when status == hidden', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.hidden), paid: 0);
      expect(d.badgeKind, DebtBadgeKind.hidden);
    });

    test('is DebtBadgeKind.none when status == active', () {
      final d = DebtWithPaid(debt: _debt(status: DebtStatus.active), paid: 0);
      expect(d.badgeKind, DebtBadgeKind.none);
    });
  });
}
