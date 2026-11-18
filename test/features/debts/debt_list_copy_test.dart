import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debt_list_copy.dart';
import 'package:perfinance/features/debts/debts_provider.dart';

Debt _debt({DebtStatus status = DebtStatus.active, double total = 1000000, int installments = 10}) => Debt(
  id: 'd1',
  userId: 'u1',
  name: 'Moto',
  totalAmount: total,
  numberOfInstallments: installments,
  dueDate: DateTime(2026, 12, 31),
  status: status,
);

void main() {
  group('debtsEmptyMessage', () {
    test('cada filtro dice qué falta, en español neutro', () {
      expect(debtsEmptyMessage(DebtListFilter.active, ''), 'No tienes deudas activas.');
      expect(debtsEmptyMessage(DebtListFilter.paid, ''), 'Todavía no pagaste ninguna deuda.');
      expect(debtsEmptyMessage(DebtListFilter.hidden, ''), 'No tienes deudas ocultas.');
      expect(debtsEmptyMessage(DebtListFilter.all, ''), 'Todavía no registraste deudas.');
    });

    test('con búsqueda nombra lo buscado', () {
      expect(debtsEmptyMessage(DebtListFilter.active, '  moto '), 'Ninguna deuda coincide con «moto».');
    });
  });

  group('debtStatusLine', () {
    test('activa: cuotas pagadas y vencimiento', () {
      final d = _debt();
      expect(
        debtStatusLine(DebtWithPaid(debt: d, paid: d.amountPerInstallment * 3), hideValues: false),
        '3 de 10 cuotas · vence 31 dic 2026',
      );
    });

    test('activa sin cuotas: solo vencimiento', () {
      final d = _debt(installments: 0);
      expect(debtStatusLine(DebtWithPaid(debt: d, paid: 0), hideValues: false), 'Vence 31 dic 2026');
    });

    test('pagada: muestra el total', () {
      final d = _debt(status: DebtStatus.paid, total: 50000);
      expect(debtStatusLine(DebtWithPaid(debt: d, paid: 0), hideValues: false), r'Total $50.000');
    });

    test('oculta: lo dice junto al vencimiento', () {
      final d = _debt(status: DebtStatus.hidden);
      expect(debtStatusLine(DebtWithPaid(debt: d, paid: 0), hideValues: false), 'Oculta · vence 31 dic 2026');
    });

    test('recibida: quién la registró', () {
      final d = Debt.mirrored(
        mirroredDebtId: 'm1',
        userId: 'u1',
        creditorEmail: 'ana@example.com',
        name: 'Préstamo',
        totalAmount: 800,
        dueDate: DateTime(2026, 12, 31),
        status: 'active',
      );
      expect(debtStatusLine(DebtWithPaid(debt: d, paid: 0), hideValues: false), 'Registrada por ana@example.com');
    });
  });

  group('vencidas', () {
    final today = DateTime(2027, 1, 5, 10);

    test('activa con saldo y fecha pasada: vencida, y la línea lo dice', () {
      final d = _debt();
      final item = DebtWithPaid(debt: d, paid: d.amountPerInstallment * 3);
      expect(isDebtOverdue(item, today), isTrue);
      expect(debtStatusLine(item, hideValues: false, today: today), '3 de 10 cuotas · venció 31 dic 2026');
    });

    test('activa sin cuotas y vencida: «Venció»', () {
      final d = _debt(installments: 0);
      expect(debtStatusLine(DebtWithPaid(debt: d, paid: 0), hideValues: false, today: today), 'Venció 31 dic 2026');
    });

    test('el mismo día del vencimiento todavía no está vencida', () {
      final item = DebtWithPaid(debt: _debt(), paid: 0);
      expect(isDebtOverdue(item, DateTime(2026, 12, 31, 23, 59)), isFalse);
      expect(
        debtStatusLine(item, hideValues: false, today: DateTime(2026, 12, 31, 23, 59)),
        '0 de 10 cuotas · vence 31 dic 2026',
      );
    });

    test('sin saldo, pagada u oculta: nunca vencida', () {
      final d = _debt(total: 100);
      expect(isDebtOverdue(DebtWithPaid(debt: d, paid: 100), today), isFalse);
      expect(isDebtOverdue(DebtWithPaid(debt: _debt(status: DebtStatus.paid), paid: 0), today), isFalse);
      expect(isDebtOverdue(DebtWithPaid(debt: _debt(status: DebtStatus.hidden), paid: 0), today), isFalse);
    });

    test('recibida activa y vencida sí; cancelada no', () {
      Debt mirrored(String status) => Debt.mirrored(
        mirroredDebtId: 'm1',
        userId: 'u1',
        creditorEmail: 'ana@example.com',
        name: 'Préstamo',
        totalAmount: 800,
        dueDate: DateTime(2026, 12, 31),
        status: status,
      );
      final active = DebtWithPaid(debt: mirrored('active'), paid: 0);
      expect(isDebtOverdue(active, today), isTrue);
      expect(debtStatusLine(active, hideValues: false, today: today), 'Registrada por ana@example.com · venció 31 dic 2026');
      expect(isDebtOverdue(DebtWithPaid(debt: mirrored('revoked'), paid: 0), today), isFalse);
    });
  });

  group('debtRemaining', () {
    test('nunca negativo', () {
      final d = _debt(total: 100);
      expect(debtRemaining(DebtWithPaid(debt: d, paid: 150)), 0);
      expect(debtRemaining(DebtWithPaid(debt: d, paid: 40)), 60);
    });
  });
}
