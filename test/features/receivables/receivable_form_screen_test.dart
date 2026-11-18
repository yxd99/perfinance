import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

    Widget buildScreen() => UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReceivableFormScreen()),
        );

    testWidgets('renders name, email, and amount fields', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('Nombre o descripción'), findsOneWidget);
      expect(find.text('Email (opcional)'), findsOneWidget);
      expect(find.text('Monto total adeudado'), findsOneWidget);
    });

    testWidgets('AppBar shows "Nueva deuda" for create mode', (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('Nueva deuda'), findsOneWidget);
    });

    testWidgets('shows validation error when name is empty on submit', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.text('Ingresá un nombre'), findsOneWidget);
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
  });
}
