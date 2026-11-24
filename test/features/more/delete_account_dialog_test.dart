import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/more/delete_account_dialog.dart';

void main() {
  bool? result;

  Widget host() => MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDeleteAccountDialog(context),
            child: const Text('abrir'),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(host());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar cuenta'));

  testWidgets('el botón queda deshabilitado hasta escribir ELIMINAR', (tester) async {
    await open(tester);
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ELIMINA');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), ' eliminar ');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('confirmar devuelve true', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'ELIMINAR');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar cuenta'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelar devuelve false', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('explica qué se borra y qué no', (tester) async {
    await open(tester);
    expect(find.textContaining('no se puede deshacer'), findsOneWidget);
    expect(find.textContaining('Las deudas que tienes con otros usuarios'), findsOneWidget);
  });
}
