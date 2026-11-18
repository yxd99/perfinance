import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/features/savings/savings_screen.dart';

Widget _app(Future<List<PaymentMethod>> Function() load) => ProviderScope(
      overrides: [
        paymentMethodsListProvider.overrideWith((ref) => load()),
        accountHueSlotsProvider.overrideWith((ref) async => const <String, int>{}),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SavingsScreen())),
    );

void main() {
  testWidgets('muestra el tipo traducido, nunca el valor crudo', (tester) async {
    await tester.pumpWidget(_app(() async => [
          PaymentMethod(id: 'a', userId: 'u', name: 'Billetera', type: 'cash'),
          PaymentMethod(id: 'b', userId: 'u', name: 'Nequi', type: 'debito'),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Billetera'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Débito'), findsOneWidget);
    expect(find.text('cash'), findsNothing);
    expect(find.text('Agregar cuenta de ahorro'), findsOneWidget);
  });

  testWidgets('sin medios lo dice y ofrece agregar uno', (tester) async {
    await tester.pumpWidget(_app(() async => []));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no tienes cuentas de ahorro'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Agregar cuenta de ahorro'), findsOneWidget);
  });

  testWidgets('si falla la carga muestra el error y reintenta', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(() async {
      calls++;
      if (calls == 1) throw Exception('db');
      return [PaymentMethod(id: 'a', userId: 'u', name: 'Billetera', type: 'other')];
    }));
    await tester.pumpAndSettle();
    expect(find.text('No se pudieron cargar las cuentas de ahorro.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Billetera'), findsOneWidget);
    expect(find.text('Otro'), findsOneWidget);
  });

  testWidgets('no repite el nombre cuando el tipo dice lo mismo', (tester) async {
    await tester.pumpWidget(_app(() async => [
          PaymentMethod(id: 'a', userId: 'u', name: 'Efectivo', type: 'cash'),
          PaymentMethod(id: 'b', userId: 'u', name: 'Nequi', type: 'debito'),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Débito'), findsOneWidget);
  });

  testWidgets('tocar un medio abre su edición; deslizar pide confirmar el borrado', (tester) async {
    await tester.pumpWidget(_app(() async => [PaymentMethod(id: 'a', userId: 'u', name: 'Nequi', type: 'debito')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Desliza'), findsNothing);

    // Mantener presionado no tiene un significado oculto.
    final inkWell = tester.widget<InkWell>(find.ancestor(of: find.text('Nequi'), matching: find.byType(InkWell)).first);
    expect(inkWell.onLongPress, isNull);

    expect(find.byType(Dismissible), findsOneWidget);
    await tester.drag(find.text('Nequi'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Nequi»?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nequi'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentMethodFormScreen), findsOneWidget);
    expect(find.text('Editar cuenta de ahorro'), findsOneWidget);
    expect(find.textContaining('no suma a la deuda de tus tarjetas'), findsOneWidget);
  });

  testWidgets('editar y eliminar están a la vista en el botón de acciones', (tester) async {
    await tester.pumpWidget(_app(() async => [PaymentMethod(id: 'a', userId: 'u', name: 'Nequi', type: 'debito')]));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Acciones de Nequi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Nequi»?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Acciones de Nequi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cuenta de ahorro'), findsOneWidget);
  });
}
