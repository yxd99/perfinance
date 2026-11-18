import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/expenses/last_account.dart';
import 'package:perfinance/features/expenses/quick_add_expense.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FakeExpenseRepository implements ExpenseRepository {
  final inserted = <Expense>[];

  @override
  Future<void> insert(Expense e) async => inserted.add(e);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSyncService implements SyncService {
  @override
  Future<void> pushPendingIfOnline() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _card = CreditCard(id: 'card-1', userId: 'u1', alias: 'Visa', cutOffDay: 15, managementFee: 0);
final _method = PaymentMethod(id: 'pm-1', userId: 'u1', name: 'Efectivo', type: 'cash');

Widget _app({List<CreditCard> cards = const [], List<PaymentMethod> methods = const [], ExpenseRepository? repo}) =>
    ProviderScope(
      overrides: [
        expensesListProvider.overrideWith((ref) async => []),
        creditCardsListProvider.overrideWith((ref) async => cards),
        activeCreditCardsListProvider.overrideWith((ref) async => cards),
        paymentMethodsListProvider.overrideWith((ref) async => methods),
        expensePaymentDisplayProvider.overrideWith(
          (ref) async => const ExpensePaymentDisplay(cardAliases: {}, methodNames: {}),
        ),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const User(id: 'u1', appMetadata: {}, userMetadata: {}, aud: '', createdAt: '')),
        ),
        syncServiceProvider.overrideWithValue(_FakeSyncService()),
        if (repo != null) expenseRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showQuickAddExpense(context, ref),
              child: const Text('+'),
            ),
          ),
        ),
      ),
    );

bool _isSelected(WidgetTester tester, String label) => tester
    .widget<ChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)))
    .selected;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el «+» abre la hoja de registro y valida monto y cuenta', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Registrá un egreso'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.text('Guardar egreso'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá el monto'), findsOneWidget);
    expect(find.text('Elegí una tarjeta o cuenta'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('la fecha «Hoy» va junto al monto y abre la rueda de fechas de iOS', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    final amountTop = tester.getTopLeft(find.byType(TextFormField).first).dy;
    final chipTop = tester.getTopLeft(find.text('Hoy')).dy;
    expect(chipTop, lessThan(amountTop), reason: 'la fecha va en la fila del monto, sin scroll');
    expect(tester.getSize(find.bySemanticsLabel(RegExp('^Fecha'))).height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('preselecciona la última cuenta usada', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_expense_payment_type': 'payment_method',
      'last_expense_payment_ref': 'pm-1',
    });
    await tester.pumpWidget(_app(cards: [_card], methods: [_method]));
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Efectivo'), isTrue);
    expect(_isSelected(tester, 'Visa'), isFalse);
  });

  testWidgets('si la última cuenta ya no existe, no preselecciona ninguna', (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_expense_payment_type': 'credit_card',
      'last_expense_payment_ref': 'card-borrada',
    });
    await tester.pumpWidget(_app(cards: [_card], methods: [_method]));
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(_isSelected(tester, 'Efectivo'), isFalse);
    expect(_isSelected(tester, 'Visa'), isFalse);
  });

  testWidgets('al guardar: vibra, cierra, confirma y recuerda la cuenta', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final repo = _FakeExpenseRepository();

    await tester.pumpWidget(_app(cards: [_card], methods: [_method], repo: repo));
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '25000');
    await tester.tap(find.text('Visa'));
    await tester.tap(find.text('Guardar egreso'));
    await tester.pumpAndSettle();

    expect(repo.inserted.single.paymentRef, 'card-1');
    expect(repo.inserted.single.amount, 25000);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Egreso registrado'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    expect(
      await LastAccountStore.load(),
      const LastAccount(paymentType: 'credit_card', paymentRef: 'card-1'),
    );
  });
}
