import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

// Helper: insert a mirrored debt row directly
Future<void> _insertMirroredDebt(
  dynamic db, {
  String id = 'mirror-1',
  String receivableId = 'recv-1',
  String debtorUserId = 'debtor-1',
  String creditorUserId = 'creditor-1',
  String creditorEmail = 'creditor@example.com',
  String debtorName = 'Test Debtor',
  double totalAmount = 1000.0,
  String status = 'active',
  String syncStatus = 'synced',
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableMirroredDebts, {
    'id': id,
    'receivable_id': receivableId,
    'debtor_user_id': debtorUserId,
    'creditor_user_id': creditorUserId,
    'creditor_email': creditorEmail,
    'debtor_name': debtorName,
    'total_amount': totalAmount,
    'status': status,
    columnSyncStatus: syncStatus,
    columnUpdatedAt: now,
    'created_at': now,
  });
}

// Helper: insert a mirrored payment row directly
Future<void> _insertMirroredPayment(
  dynamic db, {
  String id = 'mpay-1',
  String mirroredDebtId = 'mirror-1',
  String sourcePaymentId = 'spay-1',
  double amount = 200.0,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableMirroredDebtPayments, {
    'id': id,
    'mirrored_debt_id': mirroredDebtId,
    'source_payment_id': sourcePaymentId,
    'amount': amount,
    'date': now,
    columnSyncStatus: 'synced',
    columnUpdatedAt: now,
    'created_at': now,
  });
}

// Thin in-memory repo that operates on the raw db — avoids Riverpod
class _TestMirroredDebtRepository extends MirroredDebtRepository {
  _TestMirroredDebtRepository(this._rawDb);
  final dynamic _rawDb;

  @override
  Future<dynamic> get db async => _rawDb;
}

void main() {
  sqfliteFfiInit();

  late dynamic rawDb;
  late _TestMirroredDebtRepository repo;

  setUp(() async {
    rawDb = await openTestDatabase();
    repo = _TestMirroredDebtRepository(rawDb);
  });

  tearDown(() async {
    await rawDb.close();
  });

  group('getAllAsDebts', () {
    test('getAllAsDebts returns mirrored rows as Debt instances with isMirrored true', () async {
      await _insertMirroredDebt(rawDb);

      final debts = await repo.getAllAsDebts('debtor-1');

      expect(debts, hasLength(1));
      expect(debts.first, isA<Debt>());
      expect(debts.first.isMirrored, isTrue);
      expect(debts.first.creditorEmail, 'creditor@example.com');
    });
  });

  group('getTotalPaidByMirroredId', () {
    test('getTotalPaidByMirroredId sums amounts', () async {
      await _insertMirroredDebt(rawDb);
      await _insertMirroredPayment(rawDb, amount: 300.0, id: 'mpay-1');
      await _insertMirroredPayment(rawDb, amount: 150.0, id: 'mpay-2', sourcePaymentId: 'spay-2');

      final total = await repo.getTotalPaidByMirroredId('mirror-1');

      expect(total, 450.0);
    });
  });

  group('upsertFromRemote', () {
    test('upsertFromRemote replaces existing mirror', () async {
      await _insertMirroredDebt(rawDb, totalAmount: 500.0);

      // Upsert with updated amount
      await repo.upsertFromRemote({
        'id': 'mirror-1',
        'receivable_id': 'recv-1',
        'debtor_user_id': 'debtor-1',
        'creditor_user_id': 'creditor-1',
        'creditor_email': 'creditor@example.com',
        'debtor_name': 'Test Debtor',
        'total_amount': 800.0,
        'description': null,
        'due_date': null,
        'status': 'active',
        'revoked_at': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await rawDb.query(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-1']);
      expect(rows, hasLength(1));
      expect((rows.first['total_amount'] as num).toDouble(), 800.0);
    });
  });

  group('deleteByMirroredId', () {
    test('deleteByMirroredId throws StateError when status active', () async {
      await _insertMirroredDebt(rawDb, status: 'active');

      expect(
        () => repo.deleteByMirroredId('mirror-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteByMirroredId removes debt and payments when revoked', () async {
      await _insertMirroredDebt(rawDb, status: 'revoked');
      await _insertMirroredPayment(rawDb);

      await repo.deleteByMirroredId('mirror-1');

      final debts = await rawDb.query(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-1']);
      final payments = await rawDb.query(
        tableMirroredDebtPayments,
        where: 'mirrored_debt_id = ?',
        whereArgs: ['mirror-1'],
      );
      expect(debts, isEmpty);
      expect(payments, isEmpty);
    });
  });

  group('pruneAbsent', () {
    test('pruneAbsent deletes local mirrors not in remote id set', () async {
      await _insertMirroredDebt(rawDb, id: 'mirror-keep', debtorUserId: 'debtor-1');
      await _insertMirroredDebt(
        rawDb,
        id: 'mirror-gone',
        receivableId: 'recv-2',
        debtorUserId: 'debtor-1',
      );

      await repo.pruneAbsent('debtor-1', {'mirror-keep'});

      final kept = await rawDb.query(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-keep']);
      final gone = await rawDb.query(tableMirroredDebts, where: 'id = ?', whereArgs: ['mirror-gone']);
      expect(kept, hasLength(1));
      expect(gone, isEmpty);
    });
  });
}
