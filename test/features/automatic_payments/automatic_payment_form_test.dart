import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_form_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';

/// Crea el widget bajo prueba con overrides de los providers de lista.
Widget buildForm({AutomaticPayment? edit}) {
  return ProviderScope(
    overrides: [
      creditCardsListProvider.overrideWith(
        (ref) async => <CreditCard>[
          CreditCard(
            id: 'card-1',
            userId: 'user-1',
            alias: 'Visa',
            cutOffDay: 15,
            managementFee: 0,
          ),
        ],
      ),
      paymentMethodsListProvider.overrideWith(
        (ref) async => <PaymentMethod>[
          PaymentMethod(id: 'method-1', userId: 'user-1', name: 'Efectivo', type: 'cash'),
        ],
      ),
    ],
    child: MaterialApp(
      home: AutomaticPaymentFormScreen(edit: edit),
    ),
  );
}

void main() {
  group('AutomaticPaymentFormScreen', () {
    testWidgets('validación: día 0 falla', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      // Ingresar descripción y monto mínimos para llegar a la validación del día
      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');

      // Ingresar día inválido 0
      await tester.enterText(find.byType(TextFormField).at(2), '0');

      // Tocar guardar
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un día entre 1 y 31'), findsOneWidget);
    });

    testWidgets('validación: día 32 falla', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');
      await tester.enterText(find.byType(TextFormField).at(2), '32');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un día entre 1 y 31'), findsOneWidget);
    });

    testWidgets('validación: día 1 pasa', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');
      await tester.enterText(find.byType(TextFormField).at(2), '1');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // No debe aparecer el mensaje de error del día
      expect(find.text('Ingresa un día entre 1 y 31'), findsNothing);
    });

    testWidgets('validación: día 31 pasa', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Test');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');
      await tester.enterText(find.byType(TextFormField).at(2), '31');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un día entre 1 y 31'), findsNothing);
    });

    testWidgets('dropdown muestra exactamente 4 opciones de frecuencia', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      // Abrir el dropdown de frecuencia (primer DropdownButtonFormField<String>)
      final frequencyDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(frequencyDropdown);
      await tester.pumpAndSettle();

      // En un DropdownButton abierto, las opciones aparecen en overlay
      expect(find.text('Mensual'), findsWidgets);
      expect(find.text('Trimestral'), findsAtLeastNWidgets(1));
      expect(find.text('Semestral'), findsAtLeastNWidgets(1));
      expect(find.text('Anual'), findsAtLeastNWidgets(1));
    });

    testWidgets('modo edición precarga paymentDayOfMonth y frequency', (tester) async {
      // Usamos payment_method para evitar el problema del DropdownButtonFormField
      // de tarjetas que necesita que los items estén cargados antes del primer frame.
      final payment = AutomaticPayment(
        id: 'payment-1',
        userId: 'user-1',
        paymentType: 'payment_method',
        paymentRef: 'method-1',
        amount: 50000,
        description: 'Netflix',
        nextRunDate: DateTime(2024, 3, 28),
        paymentDayOfMonth: 28,
        frequency: 'trimestral',
      );

      await tester.pumpWidget(buildForm(edit: payment));
      await tester.pumpAndSettle();

      // El campo del día debe tener '28'
      expect(find.widgetWithText(TextFormField, '28'), findsOneWidget);
      // El dropdown de frecuencia debe mostrar 'Trimestral'
      expect(find.text('Trimestral'), findsOneWidget);
    });

    // --- Tests para label "Próximo pago" (TDD RED phase) ---

    testWidgets('0.1 label oculto cuando campo día está vacío', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      expect(find.textContaining('Próximo pago:'), findsNothing);
    });

    testWidgets('0.2 label visible con texto correcto cuando day=15, frequency=mensual', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(2), '15');
      await tester.pump();

      final expected = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 15,
        from: DateTime.now(),
      );

      expect(find.textContaining('Próximo pago: ${formatDisplayDate(expected)}'), findsOneWidget);
    });

    testWidgets('0.3 label se actualiza al cambiar el día de 15 a 20', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(2), '15');
      await tester.pump();

      final expected15 = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 15,
        from: DateTime.now(),
      );
      expect(find.textContaining('Próximo pago: ${formatDisplayDate(expected15)}'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(2), '20');
      await tester.pump();

      final expected20 = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 20,
        from: DateTime.now(),
      );
      expect(find.textContaining('Próximo pago: ${formatDisplayDate(expected20)}'), findsOneWidget);
    });

    testWidgets('0.4 label visible desde primer frame en modo edición con day=10, frequency=mensual',
        (tester) async {
      final payment = AutomaticPayment(
        id: 'edit-1',
        userId: 'user-1',
        paymentType: 'payment_method',
        paymentRef: 'method-1',
        amount: 10000,
        description: 'Spotify',
        nextRunDate: DateTime(2025, 1, 10),
        paymentDayOfMonth: 10,
        frequency: 'mensual',
      );

      await tester.pumpWidget(buildForm(edit: payment));
      await tester.pumpAndSettle();

      expect(find.textContaining('Próximo pago:'), findsOneWidget);
    });
  });
}
