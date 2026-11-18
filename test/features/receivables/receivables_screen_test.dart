import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/receivables/receivable_detail_screen.dart';
import 'package:perfinance/features/receivables/receivables_screen.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';

import '../../helpers/db_helper.dart';

Receivable _makeReceivable({
  String id = 'r1',
  String name = 'Juan Pérez',
  ReceivableStatus status = ReceivableStatus.active,
}) => Receivable(id: id, userId: 'u1', debtorName: name, totalAmount: 500000, status: status, syncStatus: 'synced');

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

    Widget buildScreen({
      List<ReceivableView> views = const [],
      List<ReceivableView> settled = const [],
      double total = 0,
    }) => ProviderScope(
      overrides: [
        receivableRepositoryProvider.overrideWithValue(repo),
        receivablePaymentRepositoryProvider.overrideWithValue(payRepo),
        filteredReceivablesProvider(ReceivableListFilter.active).overrideWith((_) async => views),
        filteredReceivablesProvider(ReceivableListFilter.settled).overrideWith((_) async => settled),
        filteredReceivablesProvider(ReceivableListFilter.all).overrideWith((_) async => views),
        receivablesTotalOutstandingProvider.overrideWith((_) async => total),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ReceivablesScreen()),
      ),
    );

    testWidgets('filtro segmentado: Activas, Cobradas, Todas', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(CupertinoSlidingSegmentedControl<ReceivableListFilter>), findsOneWidget);
      expect(find.text('Activas'), findsOneWidget);
      expect(find.text('Cobradas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
    });

    testWidgets('tocar "Cobradas" cambia el filtro y muestra las saldadas con sello', (tester) async {
      final settled = [
        ReceivableView(
          receivable: _makeReceivable(id: 'r2', name: 'Ana Saldada', status: ReceivableStatus.settled),
          payments: [ReceivablePayment(id: 'p1', receivableId: 'r2', amount: 500000, date: DateTime(2026, 1, 1))],
        ),
      ];
      await tester.pumpWidget(buildScreen(settled: settled));
      await tester.pumpAndSettle();
      expect(find.text('Ana Saldada'), findsNothing);

      await tester.tap(find.text('Cobradas'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(ReceivablesScreen)));
      expect(container.read(receivableListFilterProvider), ReceivableListFilter.settled);
      expect(find.text('Ana Saldada'), findsOneWidget);
      expect(find.byType(PaidStamp), findsOneWidget);
      expect(find.text('SALDADA'), findsOneWidget);
    });

    testWidgets('fila activa: "Falta" a la derecha y sin sello', (tester) async {
      final views = [
        ReceivableView(
          receivable: _makeReceivable(name: 'Juan Test'),
          payments: const [],
        ),
      ];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();
      expect(find.text('Juan Test'), findsOneWidget);
      expect(find.text('Falta \$500.000'), findsOneWidget);
      expect(find.text('Cobrado \$0 de \$500.000'), findsOneWidget);
      expect(find.byType(PaidStamp), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('muestra empty state cuando no hay cobros', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Nadie te debe'), findsOneWidget);
    });

    testWidgets('muestra el total por cobrar arriba de la lista', (tester) async {
      final views = [ReceivableView(receivable: _makeReceivable(name: 'Juan Test'), payments: const [])];
      await tester.pumpWidget(buildScreen(views: views, total: 500000));
      await tester.pumpAndSettle();
      expect(find.textContaining('Total por cobrar', findRichText: true), findsOneWidget);
    });

    testWidgets('agregar deudor es la última fila de la lista', (tester) async {
      final views = [ReceivableView(receivable: _makeReceivable(name: 'Juan Test'), payments: const [])];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InsetAddRow, 'Agregar deudor'), findsOneWidget);
    });

    testWidgets('"Falta" y el chevron van pegados al borde derecho', (tester) async {
      final views = [ReceivableView(receivable: _makeReceivable(name: 'Juan Test'), payments: const [])];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();
      final groupRight = tester.getTopRight(find.byType(Dismissible)).dx;
      final chevronRight = tester.getTopRight(find.byIcon(CupertinoIcons.chevron_right)).dx;
      final amountRight = tester.getTopRight(find.text('Falta \$500.000')).dx;
      expect(groupRight - chevronRight, lessThanOrEqualTo(16));
      expect(chevronRight - amountRight, lessThanOrEqualTo(24));
    });

    testWidgets('tocar abre el detalle; deslizar a la izquierda pide confirmar el borrado', (tester) async {
      final views = [ReceivableView(receivable: _makeReceivable(name: 'Juan Test'), payments: const [])];
      await tester.pumpWidget(buildScreen(views: views));
      await tester.pumpAndSettle();

      expect(find.byType(Dismissible), findsOneWidget);
      await tester.drag(find.text('Juan Test'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar deudor'), findsOneWidget);
      expect(find.text('Cobrar todo'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Test'), findsOneWidget);

      await tester.tap(find.text('Juan Test'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ReceivableDetailScreen), findsOneWidget);
      // «Cobrar todo» se mudó del deslizamiento al detalle.
      expect(find.text('Cobrar todo (\$500.000)'), findsOneWidget);
    });

    testWidgets('sin deudores ofrece agregar uno', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Agregar deudor'), findsWidgets);
    });
  });
}
