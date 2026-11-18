import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

class _TestMirroredDebtRepository extends MirroredDebtRepository {
  _TestMirroredDebtRepository(this._rawDb);
  final dynamic _rawDb;

  @override
  Future<dynamic> get db async => _rawDb;
}

/// Bajar de nuevo una fila padre no puede borrar sus hijas locales.
/// INSERT OR REPLACE borra la fila antes de insertarla y el ON DELETE CASCADE
/// se llevaba los pagos, incluso los pendientes de subir.
void main() {
  Future<List<Map<String, dynamic>>> rowsOf(dynamic db, String table) async =>
      (await db.query(table, orderBy: 'id') as List).cast<Map<String, dynamic>>();

  test('pull de una tarjeta conserva sus pagos y pagos mínimos', () async {
    final db = await openTestDatabase();
    addTearDown(() => db.close());
    final repo = CreditCardRepository(null, dbOverride: db);
    await repo.upsertFromRemote(CreditCard(
      id: 'card-1',
      userId: 'user-1',
      alias: 'Visa',
      cutOffDay: 15,
      managementFee: 0,
    ));
    await db.insert(tableCardPayments, {
      'id': 'pay-pending',
      'card_id': 'card-1',
      'amount': 900.0,
      'date': '2026-10-20T00:00:00.000',
      columnSyncStatus: 'pending_insert',
    });
    await db.insert(tableCardPayments, {
      'id': 'pay-synced',
      'card_id': 'card-1',
      'amount': 100.0,
      'date': '2026-10-01T00:00:00.000',
      columnSyncStatus: 'synced',
    });
    await db.insert(tableMinPaymentConfigs, {
      'id': 'min-1',
      'card_id': 'card-1',
      'amount': 50.0,
      'year': 2026,
      'month': 10,
      columnSyncStatus: 'synced',
    });

    await repo.upsertFromRemote(CreditCard(
      id: 'card-1',
      userId: 'user-1',
      alias: 'Visa Oro',
      cutOffDay: 15,
      managementFee: 0,
      updatedAt: '2026-10-12T15:55:20.968383+00:00',
    ));

    final card = (await rowsOf(db, tableCreditCards)).single;
    expect(card['alias'], 'Visa Oro');
    expect(card[columnUpdatedAt], '2026-10-12T15:55:20.968383+00:00');
    final payments = await rowsOf(db, tableCardPayments);
    expect(payments.map((p) => p['id']), ['pay-pending', 'pay-synced']);
    expect(payments.first[columnSyncStatus], 'pending_insert');
    expect(await rowsOf(db, tableMinPaymentConfigs), hasLength(1));
  });

  test('pull de una deuda conserva sus pagos', () async {
    // Base migrada: ahí debt_payments sí tiene ON DELETE CASCADE.
    final db = await openTestDatabase(fromVersion: 7);
    addTearDown(() => db.close());
    final fks = await db.rawQuery('PRAGMA foreign_key_list($tableDebtPayments)') as List;
    expect(fks.single['on_delete'], 'CASCADE');
    final repo = DebtRepository(null, dbOverride: db);
    Debt debt(String name) => Debt(
          id: 'debt-1',
          userId: 'user-1',
          name: name,
          totalAmount: 1000,
          numberOfInstallments: 10,
          dueDate: DateTime(2026, 12, 1),
        );
    await repo.upsertFromRemote(debt('Préstamo'));
    await db.insert(tableDebtPayments, {
      'id': 'dp-1',
      'debt_id': 'debt-1',
      'amount': 100.0,
      'date': '2026-10-01T00:00:00.000',
      columnSyncStatus: 'pending_insert',
    });

    await repo.upsertFromRemote(debt('Préstamo banco'));

    expect((await rowsOf(db, tableDebts)).single['name'], 'Préstamo banco');
    expect(await rowsOf(db, tableDebtPayments), hasLength(1));
    // Las lecturas tipadas siguen funcionando (las usa el dashboard).
    final debts = await repo.getAll('user-1');
    expect(debts.single.name, 'Préstamo banco');
    expect((await repo.getById('debt-1'))?.name, 'Préstamo banco');
  });

  test('pull de un "me deben" conserva sus abonos', () async {
    final db = await openTestDatabase();
    addTearDown(() => db.close());
    final repo = ReceivableRepository(null, dbOverride: db);
    Receivable receivable(double total) => Receivable(
          id: 'rec-1',
          userId: 'user-1',
          debtorName: 'Ana',
          totalAmount: total,
        );
    await repo.upsertFromRemote(receivable(500));
    await db.insert(tableReceivablePayments, {
      'id': 'rp-1',
      'receivable_id': 'rec-1',
      'amount': 100.0,
      'date': '2026-10-01T00:00:00.000',
      columnSyncStatus: 'pending_insert',
    });

    await repo.upsertFromRemote(receivable(600));

    expect((await rowsOf(db, tableReceivables)).single['total_amount'], 600.0);
    expect(await rowsOf(db, tableReceivablePayments), hasLength(1));
  });

  test('pull de una deuda espejo conserva sus pagos', () async {
    final db = await openTestDatabase();
    addTearDown(() => db.close());
    final repo = _TestMirroredDebtRepository(db);
    Map<String, dynamic> mirrored(double total) => {
          'id': 'md-1',
          'receivable_id': 'rec-1',
          'debtor_user_id': 'user-2',
          'creditor_user_id': 'user-1',
          'creditor_email': 'ana@example.com',
          'total_amount': total,
          'status': 'active',
        };
    await repo.upsertFromRemote(mirrored(500));
    await repo.upsertPaymentFromRemote({
      'id': 'mdp-1',
      'mirrored_debt_id': 'md-1',
      'source_payment_id': 'rp-1',
      'amount': 100,
      'date': '2026-10-01',
    });

    await repo.upsertFromRemote(mirrored(600));

    expect((await rowsOf(db, tableMirroredDebts)).single['total_amount'], 600.0);
    expect(await rowsOf(db, tableMirroredDebtPayments), hasLength(1));
  });

  test('abrir una base v14 vacía sync_cursors para rebajar todo', () async {
    final dir = await Directory.systemTemp.createTemp('perfinance_v15');
    final path = '${dir.path}/test.db';
    final v14 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 14, onCreate: createAppSchema),
    );
    await v14.insert(tableSyncCursors, {'table_name': 'card_payments', 'cursor': '2026-10-12T18:06:06Z'});
    await v14.close();

    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: appSchemaVersion, onUpgrade: upgradeAppSchema),
    );
    addTearDown(() => db.close());

    expect(await db.getVersion(), 15);
    expect(await db.query(tableSyncCursors), isEmpty);
  });
}
