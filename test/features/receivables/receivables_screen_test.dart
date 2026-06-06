import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivables_screen.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';

import '../../helpers/db_helper.dart';

Receivable _makeReceivable({String id = 'r1', String name = 'Juan Pérez'}) =>
    Receivable(
      id: id,
      userId: 'u1',
      debtorName: name,
      totalAmount: 500000,
      syncStatus: 'synced',
    );

void main() {
  group('ReceivablesScreen', () {
    late ReceivableRepository repo;
    late ReceivablePaymentRepository payRepo;
    late dynamic db;

    setUp(() async {
      db = await openTestDatabase();
      repo = ReceivableRepository(null, dbOverride: db);
      payRepo = ReceivablePaymentRepository(null, dbOverride: db);
    });

    tearDown(() async {
      await (db as dynamic).close();
    });

    Widget buildScreen({List<ReceivableView> views = const [], double total = 0}) =>
        ProviderScope(
          overrides: [
            receivableRepositoryProvider.overrideWithValue(repo),
            receivablePaymentRepositoryProvider.overrideWithValue(payRepo),
            filteredReceivablesProvider(ReceivableListFilter.active)
                .overrideWith((_) async => views),
            filteredReceivablesProvider(ReceivableListFilter.settled)
                .overrideWith((_) async => views),
            filteredReceivablesProvider(ReceivableListFilter.all)
                .overrideWith((_) async => views),
            receivablesTotalOutstandingProvider.overrideWith((_) async => total),
          ],
          child: const MaterialApp(home: Scaffold(body: ReceivablesScreen())),
        );

    testWidgets('shows filter chips: Activas, Cobradas, Todas', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.text('Activas'), findsOneWidget);
      expect(find.text('Cobradas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
    });

    testWidgets('shows empty state when no receivables', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Nadie te debe'), findsOneWidget);
    });

    testWidgets('shows debtor name when receivable exists', (tester) async {
      final r = _makeReceivable(name: 'Juan Test');
      final views = [ReceivableView(receivable: r, payments: const [])];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();
      expect(find.text('Juan Test'), findsOneWidget);
    });

    testWidgets('shows SummaryTotalBar with "Total por cobrar"', (tester) async {
      await tester.pumpWidget(buildScreen(total: 500000));
      await tester.pumpAndSettle();
      expect(find.text('Total por cobrar'), findsOneWidget);
    });

    testWidgets('shows Agregar deudor button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Agregar deudor'), findsWidgets);
    });

    testWidgets('shows LinearProgressIndicator in card', (tester) async {
      final r = _makeReceivable();
      final views = [ReceivableView(receivable: r, payments: const [])];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });
}
