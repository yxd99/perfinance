import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/services/pending_changes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _insertCard(dynamic db, String id, String syncStatus) async {
  await db.insert(tableCreditCards, {
    'id': id,
    'user_id': 'user-1',
    'alias': 'Visa',
    'cut_off_day': 10,
    'management_fee': 0,
    'is_active': 1,
    columnSyncStatus: syncStatus,
  });
}

Future<void> _insertDebt(dynamic db, String id, String syncStatus) async {
  await db.insert(tableDebts, {
    'id': id,
    'user_id': 'user-1',
    'name': 'Préstamo',
    'total_amount': 1000,
    'number_of_installments': 1,
    'due_date': '2026-12-31',
    'status': 'active',
    columnSyncStatus: syncStatus,
  });
}

void main() {
  late Database db;
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Schema real de la app (no la copia de db_helper) para detectar drift.
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('perfinance_test');
    db = await openAppDatabase(dir.path);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('es 0 cuando todo está sincronizado', () async {
    await _insertCard(db, 'card-1', 'synced');
    await _insertDebt(db, 'debt-1', 'synced');

    expect(await countPendingChanges(db), 0);
  });

  test('suma los pendientes de todas las tablas y todos los estados', () async {
    await _insertCard(db, 'card-1', 'synced');
    await _insertCard(db, 'card-2', 'pending_update');
    await _insertDebt(db, 'debt-1', 'pending_insert');
    await _insertDebt(db, 'debt-2', 'pending_delete');

    expect(await countPendingChanges(db), 3);
  });
}
