import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';

import '../../helpers/db_helper.dart';

void main() {
  group('ReceivableFormScreen', () {
    late ProviderContainer container;
    late ReceivableRepository repo;

    setUp(() async {
      final db = await openTestDatabase();
      repo = ReceivableRepository(null, dbOverride: db);
      container = ProviderContainer(
        overrides: [
          receivableRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() => container.dispose());

    Widget buildScreen({Receivable? edit}) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ReceivableFormScreen(editReceivable: edit)),
        );

    testWidgets('renders responsible name, description, email, and amount fields', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('Nombre del responsable'), findsOneWidget);
      expect(find.text('Descripción (opcional)'), findsOneWidget);
      expect(find.text('Email (opcional)'), findsOneWidget);
      expect(find.text('Monto total adeudado'), findsOneWidget);
    });

    testWidgets('AppBar shows "Nuevo cobro" for create mode', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('Nuevo cobro'), findsOneWidget);
    });

    testWidgets('shows validation error when name is empty on submit', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.text('Ingresá el nombre del responsable'), findsOneWidget);
    });

    testWidgets('shows email validation error on invalid format', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email (opcional)'),
        'not-an-email',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.textContaining('Email inválido'), findsOneWidget);
    });

    testWidgets('shows "Guardar" FilledButton', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.widgetWithText(FilledButton, 'Guardar'), findsOneWidget);
    });

    testWidgets('shows caption below email field', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.textContaining('notificarle los cobros'), findsOneWidget);
    });

    testWidgets('edit saves responsible name and description', (tester) async {
      final original = Receivable(
        id: 'r1',
        userId: 'u1',
        debtorName: 'Juan',
        totalAmount: 100000,
      );
      await tester.runAsync(() => repo.insert(original));
      await tester.pumpWidget(buildScreen(edit: original));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del responsable'),
        'Juan Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción (opcional)'),
        '  Préstamo para el carro  ',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      final saved = await tester.runAsync(() => repo.getById('r1'));
      expect(saved!.debtorName, 'Juan Pérez');
      expect(saved.description, 'Préstamo para el carro');
    });

    testWidgets('edit clears description when left blank', (tester) async {
      final original = Receivable(
        id: 'r2',
        userId: 'u1',
        debtorName: 'Ana',
        totalAmount: 50000,
        description: 'Almuerzo',
      );
      await tester.runAsync(() => repo.insert(original));
      await tester.pumpWidget(buildScreen(edit: original));

      expect(find.text('Almuerzo'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción (opcional)'),
        '   ',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      final saved = await tester.runAsync(() => repo.getById('r2'));
      expect(saved!.description, isNull);
    });
  });
}
