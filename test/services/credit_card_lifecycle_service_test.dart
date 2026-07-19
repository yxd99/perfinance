import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/services/credit_card_lifecycle_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late CreditCardRepository cardRepo;
  late AutomaticPaymentRepository autoPayRepo;

  setUp(() async {
    db = await openTestDatabase();
    cardRepo = CreditCardRepository(null, dbOverride: db);
    autoPayRepo = AutomaticPaymentRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCard(String id, {bool isActive = true}) async {
    await cardRepo.insert(CreditCard(
      id: id,
      userId: 'user-1',
      alias: 'Visa',
      cutOffDay: 10,
      managementFee: 0,
      isActive: isActive,
    ));
    await db.update(tableCreditCards, {columnSyncStatus: 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertAutoPayment(String id, String cardId, {String status = 'active'}) async {
    await autoPayRepo.insert(AutomaticPayment(
      id: id,
      userId: 'user-1',
      paymentType: 'credit_card',
      paymentRef: cardId,
      amount: 1000,
      description: 'Pago tarjeta',
      nextRunDate: DateTime(2026, 7, 10),
      status: status,
    ));
    await db.update(tableAutomaticPayments, {columnSyncStatus: 'synced'}, where: 'id = ?', whereArgs: [id]);
  }

  group('CreditCardLifecycleService.setActive', () {
    test('setActive(false) marca la tarjeta inactiva y pausa automatic_payments ligados', () async {
      await insertCard('card-1');
      await insertAutoPayment('auto-1', 'card-1');

      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, 'card-1', false);

      final card = await cardRepo.getById('card-1');
      expect(card!.isActive, false);
      final payments = await autoPayRepo.getAll('user-1');
      expect(payments.first.status, 'paused');
    });

    test('setActive(true) reactiva la tarjeta pero NO reactiva automatic_payments pausados', () async {
      await insertCard('card-1', isActive: false);
      await insertAutoPayment('auto-1', 'card-1', status: 'paused');

      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, 'card-1', true);

      final card = await cardRepo.getById('card-1');
      expect(card!.isActive, true);
      final payments = await autoPayRepo.getAll('user-1');
      expect(payments.first.status, 'paused',
          reason: 'reactivar la tarjeta no debe auto-reactivar pagos automáticos (manual por diseño)');
    });

    test('setActive(false) en tarjeta sin automatic_payments ligados no falla', () async {
      await insertCard('card-1');
      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, 'card-1', false);
      final card = await cardRepo.getById('card-1');
      expect(card!.isActive, false);
    });

    test('setActive es idempotente si se llama dos veces seguidas con el mismo valor', () async {
      await insertCard('card-1');
      await insertAutoPayment('auto-1', 'card-1');
      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, 'card-1', false);
      await CreditCardLifecycleService.setActive(cardRepo, autoPayRepo, 'card-1', false);
      final card = await cardRepo.getById('card-1');
      expect(card!.isActive, false);
      final payments = await autoPayRepo.getAll('user-1');
      expect(payments.first.status, 'paused');
    });
  });
}
