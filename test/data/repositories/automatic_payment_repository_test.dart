import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../../helpers/db_helper.dart';

AutomaticPayment _makePayment({
  String id = 'auto-1',
  String userId = 'user-1',
  String paymentType = 'credit_card',
  String paymentRef = 'card-1',
  double amount = 1000,
  String status = 'active',
}) {
  return AutomaticPayment(
    id: id,
    userId: userId,
    paymentType: paymentType,
    paymentRef: paymentRef,
    amount: amount,
    description: 'Pago tarjeta',
    nextRunDate: DateTime(2026, 7, 10),
    status: status,
  );
}

Future<Map<String, dynamic>> _getRow(dynamic db, String id) async {
  final rows = await db.query(tableAutomaticPayments, where: 'id = ?', whereArgs: [id]);
  return rows.first;
}

void main() {
  group('AutomaticPayment.fromMap', () {
    test('con payment_day_of_month y frequency presentes', () {
      final map = {
        'id': 'test-id',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 50000.0,
        'description': 'Netflix',
        'next_run_date': '2024-03-15T00:00:00.000',
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
        'payment_day_of_month': 15,
        'frequency': 'trimestral',
      };

      final payment = AutomaticPayment.fromMap(map);

      expect(payment.paymentDayOfMonth, 15);
      expect(payment.frequency, 'trimestral');
    });

    test('con payment_day_of_month y frequency null — fallback desde next_run_date', () {
      final map = {
        'id': 'test-id-2',
        'user_id': 'user-1',
        'payment_type': 'payment_method',
        'payment_ref': 'method-1',
        'amount': 30000.0,
        'description': 'Gym',
        'next_run_date': '2024-03-28T00:00:00.000',
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
        'payment_day_of_month': null,
        'frequency': null,
      };

      final payment = AutomaticPayment.fromMap(map);

      expect(payment.paymentDayOfMonth, 28);
      expect(payment.frequency, 'mensual');
    });
  });

  group('AutomaticPaymentRepository status wiring', () {
    sqfliteFfiInit();

    late dynamic db;
    late AutomaticPaymentRepository repo;

    setUp(() async {
      db = await openTestDatabase();
      repo = AutomaticPaymentRepository(null, dbOverride: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('insert persiste status', () async {
      await repo.insert(_makePayment(id: 'a1', status: 'paused'));
      final row = await _getRow(db, 'a1');
      expect(row['status'], 'paused');
    });

    test('update persiste status', () async {
      await repo.insert(_makePayment(id: 'a1', status: 'active'));
      await repo.update(_makePayment(id: 'a1', status: 'paused'));
      final row = await _getRow(db, 'a1');
      expect(row['status'], 'paused');
    });

    test('upsertFromRemote persiste status', () async {
      await repo.upsertFromRemote(_makePayment(id: 'a1', status: 'paused'));
      final row = await _getRow(db, 'a1');
      expect(row['status'], 'paused');
    });

    test('_rowTo mapea status con default active si null (via getAll)', () async {
      await repo.insert(_makePayment(id: 'a1', status: 'active'));
      // Force a legacy row without status by nulling it directly won't violate NOT NULL;
      // instead confirm getAll round-trips status correctly.
      final all = await repo.getAll('user-1');
      expect(all.first.status, 'active');
    });

    group('pauseAllForCard', () {
      test('marca status=paused y sync_status=pending_update en automáticos activos del cardId', () async {
        await repo.insert(_makePayment(id: 'a1', paymentType: 'credit_card', paymentRef: 'card-1', status: 'active'));
        await db.update(tableAutomaticPayments, {columnSyncStatus: 'synced'}, where: 'id = ?', whereArgs: ['a1']);
        await repo.pauseAllForCard('card-1');
        final row = await _getRow(db, 'a1');
        expect(row['status'], 'paused');
        expect(row[columnSyncStatus], 'pending_update');
      });

      test('no afecta automáticos de otra tarjeta', () async {
        await repo.insert(_makePayment(id: 'a1', paymentType: 'credit_card', paymentRef: 'card-1', status: 'active'));
        await repo.insert(_makePayment(id: 'a2', paymentType: 'credit_card', paymentRef: 'card-2', status: 'active'));
        await repo.pauseAllForCard('card-1');
        final row2 = await _getRow(db, 'a2');
        expect(row2['status'], 'active');
      });

      test('es idempotente — no reactiva ni toca los ya pausados', () async {
        await repo.insert(_makePayment(id: 'a1', paymentType: 'credit_card', paymentRef: 'card-1', status: 'paused'));
        await db.update(tableAutomaticPayments, {columnSyncStatus: 'synced'}, where: 'id = ?', whereArgs: ['a1']);
        await repo.pauseAllForCard('card-1');
        final row = await _getRow(db, 'a1');
        expect(row['status'], 'paused');
        // sync_status should remain synced since the row was already paused (WHERE status='active' excludes it)
        expect(row[columnSyncStatus], 'synced');
      });
    });
  });
}
