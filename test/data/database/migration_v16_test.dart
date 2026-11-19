import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/db_helper.dart';

Future<Set<String>> _columns(dynamic db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)') as List;
  return {for (final r in rows) r['name'] as String};
}

void main() {
  test('instalación nueva: tarjetas y cuentas de ahorro guardan color_slot', () async {
    final db = await openTestDatabase();
    expect(await _columns(db, tableCreditCards), contains('color_slot'));
    expect(await _columns(db, tablePaymentMethods), contains('color_slot'));
    await db.close();
  });

  test('upgrade desde v15 agrega color_slot vacío sin tocar las filas', () async {
    final db = await openTestDatabase(fromVersion: 15);
    expect(await _columns(db, tableCreditCards), contains('color_slot'));
    expect(await _columns(db, tablePaymentMethods), contains('color_slot'));
    await db.insert(tablePaymentMethods, {'id': 'pm', 'user_id': 'u', 'name': 'Nequi'});
    final row = (await db.query(tablePaymentMethods) as List).single;
    expect(row['color_slot'], isNull);
    await db.close();
  });

  test('upgrade desde v15 real: conserva las filas y vuelve a bajar tarjetas y cuentas', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('perfinance_v16');
    final path = '${dir.path}/test.db';
    // Una v15 de verdad: el esquema actual sin color_slot, con datos y cursores.
    final v15 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 15, onCreate: createAppSchema),
    );
    await v15.execute('ALTER TABLE $tableCreditCards DROP COLUMN color_slot');
    await v15.execute('ALTER TABLE $tablePaymentMethods DROP COLUMN color_slot');
    await v15.insert(tableCreditCards, {'id': 'c', 'user_id': 'u', 'alias': 'Visa', 'cut_off_day': 15});
    await v15.insert(tablePaymentMethods, {'id': 'p', 'user_id': 'u', 'name': 'Nequi'});
    for (final t in [tableCreditCards, tablePaymentMethods, tableExpenses]) {
      await v15.insert(tableSyncCursors, {'table_name': t, 'cursor': '2026-11-01T00:00:00Z'});
    }
    await v15.close();

    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: appSchemaVersion, onUpgrade: upgradeAppSchema),
    );
    addTearDown(() => db.close());

    final card = (await db.query(tableCreditCards)).single;
    expect(card['alias'], 'Visa');
    expect(card['color_slot'], isNull);
    expect((await db.query(tablePaymentMethods)).single['color_slot'], isNull);
    // Sin cursor, la próxima bajada trae el color que otro dispositivo ya eligió.
    final cursors = {for (final r in await db.query(tableSyncCursors)) r['table_name']};
    expect(cursors, {tableExpenses});
  });
}

