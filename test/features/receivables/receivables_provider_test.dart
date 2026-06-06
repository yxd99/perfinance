import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/db_helper.dart';

void main() {
  late ProviderContainer container;
  late ReceivableRepository repo;
  late ReceivablePaymentRepository payRepo;
  late dynamic db;

  const userId = 'user-test';

  Receivable _makeReceivable({
    String id = 'r1',
    ReceivableStatus status = ReceivableStatus.active,
    double totalAmount = 1000,
  }) =>
      Receivable(
        id: id,
        userId: userId,
        debtorName: 'Test Debtor',
        debtorEmail: 'test@example.com',
        totalAmount: totalAmount,
        status: status,
        syncStatus: 'synced',
      );

  ReceivablePayment _makePayment({
    String id = 'p1',
    String receivableId = 'r1',
    double amount = 200,
  }) =>
      ReceivablePayment(
        id: id,
        receivableId: receivableId,
        amount: amount,
        date: DateTime(2026, 6, 1),
        syncStatus: 'synced',
      );

  setUp(() async {
    db = await openTestDatabase();
    repo = ReceivableRepository(null, dbOverride: db);
    payRepo = ReceivablePaymentRepository(null, dbOverride: db);

    container = ProviderContainer(
      overrides: [
        receivableRepositoryProvider.overrideWithValue(repo),
        receivablePaymentRepositoryProvider.overrideWithValue(payRepo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            _FakeUser(userId),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await (db as dynamic).close();
  });

  group('ReceivableView', () {
    test('remainingBalance = totalAmount - totalPaid', () {
      final r = _makeReceivable(totalAmount: 500);
      final payments = [_makePayment(amount: 150), _makePayment(id: 'p2', amount: 100)];
      final view = ReceivableView(receivable: r, payments: payments);
      expect(view.totalPaid, 250);
      expect(view.remainingBalance, 250);
    });

    test('isFullyPaid true when remaining <= 0', () {
      final r = _makeReceivable(totalAmount: 300);
      final payments = [_makePayment(amount: 300)];
      final view = ReceivableView(receivable: r, payments: payments);
      expect(view.isFullyPaid, isTrue);
    });

    test('isFullyPaid false when remaining > 0', () {
      final r = _makeReceivable(totalAmount: 300);
      final payments = [_makePayment(amount: 100)];
      final view = ReceivableView(receivable: r, payments: payments);
      expect(view.isFullyPaid, isFalse);
    });
  });

  group('filteredReceivablesProvider', () {
    setUp(() async {
      await repo.insert(_makeReceivable(id: 'r-active', status: ReceivableStatus.active));
      await repo.upsertFromRemote(_makeReceivable(id: 'r-settled', status: ReceivableStatus.settled, totalAmount: 500));
      await repo.upsertFromRemote(_makeReceivable(id: 'r-hidden', status: ReceivableStatus.hidden, totalAmount: 200));
      await repo.upsertFromRemote(_makeReceivable(id: 'r-written', status: ReceivableStatus.writtenOff, totalAmount: 100));
    });

    test('active filter returns only active receivables', () async {
      final views = await container.read(
        filteredReceivablesProvider(ReceivableListFilter.active).future,
      );
      expect(views.map((v) => v.receivable.id), containsAll(['r-active']));
      expect(views.length, 1);
    });

    test('settled filter returns only settled receivables', () async {
      final views = await container.read(
        filteredReceivablesProvider(ReceivableListFilter.settled).future,
      );
      expect(views.map((v) => v.receivable.id), containsAll(['r-settled']));
      expect(views.length, 1);
    });

    test('all filter returns active + settled, excludes hidden and writtenOff', () async {
      final views = await container.read(
        filteredReceivablesProvider(ReceivableListFilter.all).future,
      );
      final ids = views.map((v) => v.receivable.id).toList();
      expect(ids, containsAll(['r-active', 'r-settled']));
      expect(ids, isNot(contains('r-hidden')));
      expect(ids, isNot(contains('r-written')));
    });
  });

  group('receivablePaymentsProvider', () {
    test('returns payments for a receivable', () async {
      await repo.insert(_makeReceivable(id: 'r1'));
      await payRepo.insert(_makePayment(id: 'p1', receivableId: 'r1', amount: 100));
      await payRepo.insert(_makePayment(id: 'p2', receivableId: 'r1', amount: 200));

      final payments = await container.read(
        receivablePaymentsProvider('r1').future,
      );
      expect(payments.length, 2);
    });
  });

  group('receivablesTotalOutstandingProvider', () {
    test('sums remaining for active receivables only', () async {
      await repo.insert(_makeReceivable(id: 'r-a1', totalAmount: 1000, status: ReceivableStatus.active));
      await repo.insert(_makeReceivable(id: 'r-a2', totalAmount: 500, status: ReceivableStatus.active));
      await repo.upsertFromRemote(_makeReceivable(id: 'r-s', totalAmount: 800, status: ReceivableStatus.settled));

      await payRepo.insert(_makePayment(id: 'p1', receivableId: 'r-a1', amount: 300));

      final total = await container.read(receivablesTotalOutstandingProvider.future);
      expect(total, 1200); // (1000-300) + 500
    });
  });
}

class _FakeUser implements User {
  _FakeUser(this.id);

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
