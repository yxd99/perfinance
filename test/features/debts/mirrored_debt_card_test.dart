import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:perfinance/features/debts/debts_screen.dart';

// Helper: build a minimal widget with a specific debt card rendered
Widget _buildCard(DebtWithPaid item) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: _MirroredDebtCardWrapper(item: item),
      ),
    ),
  );
}

// Expose the _DebtCard internals by extracting a test-visible version
// We test via the DebtsScreen list logic — inject debtsListProvider override
Debt _mirroredDebt({
  String creditorEmail = 'acreedor@example.com',
  String status = 'active',
}) =>
    Debt.mirrored(
      mirroredDebtId: 'mirror-test-1',
      userId: 'debtor-1',
      creditorEmail: creditorEmail,
      name: 'Deuda espejada test',
      totalAmount: 800.0,
      dueDate: DateTime(2099, 12, 31),
      status: status,
    );

class _MirroredDebtCardWrapper extends StatelessWidget {
  const _MirroredDebtCardWrapper({required this.item});
  final DebtWithPaid item;

  @override
  Widget build(BuildContext context) {
    // Directly render the card via MirroredDebtCard (public widget)
    return MirroredDebtCard(item: item);
  }
}

void main() {
  group('MirroredDebtCard — active mirrored debt', () {
    late Debt mirroredActive;
    late DebtWithPaid itemActive;

    setUp(() {
      mirroredActive = _mirroredDebt();
      itemActive = DebtWithPaid(debt: mirroredActive, paid: 0);
    });

    testWidgets('mirrored debt card shows Recibida badge', (tester) async {
      await tester.pumpWidget(_buildCard(itemActive));
      await tester.pump();
      expect(find.text('Recibida'), findsOneWidget);
    });

    testWidgets('mirrored debt card shows Registrada por {creditorEmail}', (tester) async {
      await tester.pumpWidget(_buildCard(itemActive));
      await tester.pump();
      expect(find.textContaining('Registrada por'), findsOneWidget);
      expect(find.textContaining('acreedor@example.com'), findsOneWidget);
    });

    testWidgets('mirrored debt card has NO swipe-to-pay Dismissible', (tester) async {
      await tester.pumpWidget(_buildCard(itemActive));
      await tester.pump();
      // There must be no Dismissible widget in the mirrored card
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('mirrored debt card hides edit/menu actions', (tester) async {
      await tester.pumpWidget(_buildCard(itemActive));
      await tester.pump();
      // No edit icon button in the mirrored card
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('active mirrored debt card shows NO delete button', (tester) async {
      await tester.pumpWidget(_buildCard(itemActive));
      await tester.pump();
      // No delete button for active mirrored debts
      expect(find.text('Eliminar'), findsNothing);
    });
  });

  group('MirroredDebtCard — revoked mirrored debt', () {
    late Debt mirroredRevoked;
    late DebtWithPaid itemRevoked;

    setUp(() {
      mirroredRevoked = _mirroredDebt(status: 'revoked');
      itemRevoked = DebtWithPaid(debt: mirroredRevoked, paid: 0);
    });

    testWidgets('revoked mirrored debt card shows grey cancelada banner and a delete button', (tester) async {
      await tester.pumpWidget(_buildCard(itemRevoked));
      await tester.pump();
      // Grey "cancelada" banner
      expect(find.textContaining('cancelada'), findsOneWidget);
      // Delete button present
      expect(find.text('Eliminar'), findsOneWidget);
    });
  });
}
