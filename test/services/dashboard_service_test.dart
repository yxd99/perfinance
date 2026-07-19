import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/services/dashboard_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late CreditCardRepository cardRepo;
  late ExpenseRepository expenseRepo;

  setUp(() async {
    db = await openTestDatabase();
    cardRepo = CreditCardRepository(null, dbOverride: db);
    expenseRepo = ExpenseRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCard(String id, {bool isActive = true}) async {
    await cardRepo.insert(CreditCard(
      id: id,
      userId: 'user-1',
      alias: 'Card $id',
      cutOffDay: 10,
      managementFee: 0,
      isActive: isActive,
    ));
  }

  Future<void> insertExpense(String id, String cardId, DateTime date, double amount) async {
    await expenseRepo.insert(Expense(
      id: id,
      userId: 'user-1',
      amount: amount,
      date: date,
      paymentType: 'credit_card',
      paymentRef: cardId,
    ));
  }

  group('usagePerCard', () {
    test('incluye tarjeta inactiva solo si count > 0 en el mes', () async {
      await insertCard('c1', isActive: false);
      final month = DateTime(2026, 7, 1);
      await insertExpense('e1', 'c1', DateTime(2026, 7, 5), 100);

      final usage = await DashboardService.usagePerCard(cardRepo, expenseRepo, 'user-1', forMonth: month);
      expect(usage.map((u) => u.cardId), contains('c1'));
      expect(usage.firstWhere((u) => u.cardId == 'c1').count, 1);
    });

    test('excluye tarjeta inactiva con count == 0', () async {
      await insertCard('c1', isActive: false);
      final month = DateTime(2026, 7, 1);

      final usage = await DashboardService.usagePerCard(cardRepo, expenseRepo, 'user-1', forMonth: month);
      expect(usage.map((u) => u.cardId), isNot(contains('c1')));
    });

    test('siempre incluye tarjeta activa aunque count == 0', () async {
      await insertCard('c1', isActive: true);
      final month = DateTime(2026, 7, 1);

      final usage = await DashboardService.usagePerCard(cardRepo, expenseRepo, 'user-1', forMonth: month);
      expect(usage.map((u) => u.cardId), contains('c1'));
    });
  });

  group('comparisonPerCard', () {
    test('incluye tarjeta inactiva solo si thisMonth > 0 OR lastMonth > 0', () async {
      await insertCard('c1', isActive: false);
      final ref = DateTime(2026, 7, 15);
      await insertExpense('e1', 'c1', DateTime(2026, 6, 5), 200); // lastMonth

      final comparison = await DashboardService.comparisonPerCard(cardRepo, expenseRepo, 'user-1', forMonth: ref);
      expect(comparison.map((c) => c.cardId), contains('c1'));
      expect(comparison.firstWhere((c) => c.cardId == 'c1').lastMonth, 200);
    });

    test('excluye tarjeta inactiva con ambos meses en 0', () async {
      await insertCard('c1', isActive: false);
      final ref = DateTime(2026, 7, 15);

      final comparison = await DashboardService.comparisonPerCard(cardRepo, expenseRepo, 'user-1', forMonth: ref);
      expect(comparison.map((c) => c.cardId), isNot(contains('c1')));
    });
  });
}
