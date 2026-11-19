import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:perfinance/features/debts/debts_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debt _debt(String id, String name, DebtStatus status, {DateTime? due}) => Debt(
  id: id,
  userId: 'u1',
  name: name,
  totalAmount: 100000,
  numberOfInstallments: 4,
  dueDate: due ?? DateTime(2099, 12, 31),
  status: status,
);

Widget _app(List<DebtWithPaid> list) => ProviderScope(
  overrides: [
    debtsListProvider.overrideWith((ref) async => list.map((e) => e.debt).toList()),
    filteredDebtsWithPaidProvider.overrideWith((ref) async {
      // Respeta el filtro elegido para comprobar que el control lo cambia.
      final f = ref.watch(debtListFilterProvider);
      return switch (f) {
        DebtListFilter.paid => list.where((e) => e.isPaid).toList(),
        DebtListFilter.active => list.where((e) => e.debt.status == DebtStatus.active).toList(),
        _ => list,
      };
    }),
    outstandingDebtsTotalProvider.overrideWith((ref) async => 75000),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: DebtsScreen()),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final active = DebtWithPaid(debt: _debt('a', 'Moto', DebtStatus.active), paid: 25000);
  final paid = DebtWithPaid(debt: _debt('p', 'Celular', DebtStatus.paid), paid: 100000);

  testWidgets('el control segmentado cambia el filtro', (tester) async {
    await tester.pumpWidget(_app([active, paid]));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSlidingSegmentedControl<DebtListFilter>), findsOneWidget);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('Celular'), findsNothing);

    await tester.tap(find.text('Pagadas'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(DebtsScreen)));
    expect(container.read(debtListFilterProvider), DebtListFilter.paid);
    expect(find.text('Celular'), findsOneWidget);
    expect(find.text('Moto'), findsNothing);
  });

  testWidgets('la deuda pagada queda visible con el sello', (tester) async {
    await tester.pumpWidget(_app([active, paid]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();

    expect(find.text('Celular'), findsOneWidget);
    expect(find.byType(PaidStamp), findsOneWidget);
    expect(find.text('PAGADA'), findsOneWidget);
  });

  testWidgets('activa: cuotas y lo que falta; total discreto; acción de agregar', (tester) async {
    await tester.pumpWidget(_app([active]));
    await tester.pumpAndSettle();

    expect(find.text('1 de 4 cuotas · vence 31 dic 2099'), findsOneWidget);
    expect(find.text(r'$75.000'), findsOneWidget);
    // Lo que se debe y no está vencido va en tinta, no en rojo.
    final c = AppTheme.light.extension<AppColors>()!;
    expect(tester.widget<Text>(find.text(r'$75.000')).style?.color, c.ink);
    expect(find.textContaining('Total por pagar'), findsOneWidget);
    // La acción de agregar dice qué agrega: no es un «+» suelto junto al título.
    expect(find.widgetWithText(TextButton, 'Nueva deuda'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.add), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('vencida: el monto en rojo y la línea dice «venció»', (tester) async {
    final overdueDebt = DebtWithPaid(debt: _debt('v', 'Préstamo', DebtStatus.active, due: DateTime(2020, 3, 1)), paid: 25000);
    await tester.pumpWidget(_app([overdueDebt]));
    await tester.pumpAndSettle();

    expect(find.text('1 de 4 cuotas · venció 1 mar 2020'), findsOneWidget);
    final c = AppTheme.light.extension<AppColors>()!;
    expect(tester.widget<Text>(find.text(r'$75.000')).style?.color, c.danger);
  });

  testWidgets('vacío: mensaje honesto en español neutro', (tester) async {
    await tester.pumpWidget(_app([]));
    await tester.pumpAndSettle();
    expect(find.text('No tienes deudas activas.'), findsOneWidget);
    expect(find.text('Ver todas'), findsOneWidget);
  });

  testWidgets('las acciones de una deuda están a la vista, sin mantener presionado', (tester) async {
    await tester.pumpWidget(_app([active]));
    await tester.pumpAndSettle();

    for (final ink in tester.widgetList<InkWell>(find.byType(InkWell))) {
      expect(ink.onLongPress, isNull);
    }
    await tester.tap(find.bySemanticsLabel('Acciones de Moto'));
    await tester.pumpAndSettle();
    expect(find.text('Marcar como pagada'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    await tester.tap(find.text('Marcar como pagada'));
    await tester.pumpAndSettle();
    expect(find.text('¿Marcar «Moto» como pagada?'), findsOneWidget);
  });
}

