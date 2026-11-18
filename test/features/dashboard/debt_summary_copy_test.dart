import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/dashboard/debt_summary_copy.dart';
import 'package:perfinance/services/dashboard_service.dart';

DebtBreakdownItem _item(String id, double balance, {required bool card}) =>
    DebtBreakdownItem(id: id, label: id, isCreditCard: card, balance: balance);

void main() {
  group('debtTotalParts', () {
    test('explica la suma: deudas primero, después tarjetas', () {
      final d = DebtBreakdown(total: 10265000, items: [
        _item('Visa', 1000000, card: true),
        _item('Master', 273000, card: true),
        _item('Moto', 8992000, card: false),
      ]);
      expect(debtTotalParts(d, hideValues: false), r'Deudas $8.992.000 · Tarjetas $1.273.000');
    });

    test('solo nombra lo que existe', () {
      expect(
        debtTotalParts(DebtBreakdown(total: 500, items: [_item('Visa', 500, card: true)]), hideValues: false),
        r'Tarjetas $500',
      );
      expect(
        debtTotalParts(DebtBreakdown(total: 700, items: [_item('Moto', 700, card: false)]), hideValues: false),
        r'Deudas $700',
      );
    });

    test('sin saldo no hay línea', () {
      expect(debtTotalParts(const DebtBreakdown(total: 0, items: []), hideValues: false), isNull);
    });

    test('con valores ocultos esconde los montos pero no qué incluye', () {
      final d = DebtBreakdown(total: 1200, items: [_item('Visa', 500, card: true), _item('Moto', 700, card: false)]);
      expect(debtTotalParts(d, hideValues: true), r'Deudas $•••••• · Tarjetas $••••••');
    });
  });
}
