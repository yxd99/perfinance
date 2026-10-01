import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/db_helper.dart';

AutomaticPayment _makePayment({
  required String id,
  required DateTime nextRunDate,
  String status = 'active',
  String frequency = 'mensual',
  double amount = 1000,
  String userId = 'user-1',
  String paymentType = 'payment_method',
  String paymentRef = 'method-1',
  int? paymentDayOfMonth,
}) {
  return AutomaticPayment(
    id: id,
    userId: userId,
    paymentType: paymentType,
    paymentRef: paymentRef,
    amount: amount,
    description: 'Pago $id',
    nextRunDate: nextRunDate,
    frequency: frequency,
    status: status,
    paymentDayOfMonth: paymentDayOfMonth ?? nextRunDate.day,
  );
}

void main() {
  sqfliteFfiInit();

  const userId = 'user-1';
  late dynamic db;
  late AutomaticPaymentRepository repo;
  late ProviderContainer container;

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 10);
  final otherMonth = DateTime(
    now.month == 12 ? now.year + 1 : now.year,
    now.month == 12 ? 1 : now.month + 1,
    10,
  );

  setUp(() async {
    db = await openTestDatabase();
    repo = AutomaticPaymentRepository(null, dbOverride: db);
    container = ProviderContainer(
      overrides: [
        automaticPaymentRepositoryProvider.overrideWithValue(repo),
        databaseProvider.overrideWith((ref) async => db),
        authStateProvider.overrideWith((ref) => Stream.value(_FakeUser(userId))),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('excluye pagos anuales fuera del mes actual', () async {
    await repo.insert(_makePayment(
      id: 'annual-out',
      nextRunDate: otherMonth,
      frequency: 'anual',
      amount: 5000,
    ));

    final summary = await container.read(dashboardAutomaticPaymentsSummaryProvider.future);
    expect(summary.totalPerMonth, 0);
  });

  test('suma pagos mensuales del mes actual', () async {
    await repo.insert(_makePayment(
      id: 'monthly-in',
      nextRunDate: thisMonth,
      frequency: 'mensual',
      amount: 1500,
    ));

    final summary = await container.read(dashboardAutomaticPaymentsSummaryProvider.future);
    expect(summary.totalPerMonth, 1500);
  });

  test('suma pago mensual ya cobrado este mes aunque next_run_date ya haya avanzado al próximo mes', () async {
    await repo.insert(_makePayment(
      id: 'monthly-already-charged',
      nextRunDate: otherMonth, // el cron ya corrió y avanzó la fecha
      frequency: 'mensual',
      amount: 1800,
      paymentDayOfMonth: thisMonth.day, // se cobró el día 10 de este mes
    ));

    final summary = await container.read(dashboardAutomaticPaymentsSummaryProvider.future);
    expect(summary.totalPerMonth, 1800);
  });

  test('suma pago trimestral cuya próxima ejecución cae este mes', () async {
    await repo.insert(_makePayment(
      id: 'quarterly-in',
      nextRunDate: thisMonth,
      frequency: 'trimestral',
      amount: 3000,
    ));

    final summary = await container.read(dashboardAutomaticPaymentsSummaryProvider.future);
    expect(summary.totalPerMonth, 3000);
  });

  test('excluye pagos pausados aunque caigan en el mes actual', () async {
    await repo.insert(_makePayment(
      id: 'paused-in',
      nextRunDate: thisMonth,
      status: 'paused',
      amount: 2000,
    ));

    final summary = await container.read(dashboardAutomaticPaymentsSummaryProvider.future);
    expect(summary.totalPerMonth, 0);
  });
}

class _FakeUser implements User {
  _FakeUser(this.id);

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
