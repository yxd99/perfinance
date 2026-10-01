import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';

import '../../helpers/db_helper.dart';

Future<bool> _hasSyncCursors(dynamic db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [tableSyncCursors],
  ) as List;
  return rows.isNotEmpty;
}

void main() {
  test('instalación nueva crea sync_cursors', () async {
    final db = await openTestDatabase();

    expect(await _hasSyncCursors(db), isTrue);
    await db.close();
  });

  test('upgrade desde v11 crea sync_cursors vacía', () async {
    final db = await openTestDatabase(fromVersion: 11);

    expect(await _hasSyncCursors(db), isTrue);
    expect(await db.query(tableSyncCursors), isEmpty);
    await db.close();
  });

  test('guarda un cursor por tabla y lo reemplaza', () async {
    final db = await openTestDatabase();
    await db.insert(tableSyncCursors, {'table_name': 'expenses', 'cursor': 'a'});
    await db.execute(
      'INSERT OR REPLACE INTO $tableSyncCursors (table_name, cursor) VALUES (?, ?)',
      ['expenses', 'b'],
    );

    final rows = await db.query(tableSyncCursors) as List;
    expect(rows, hasLength(1));
    expect(rows.first['cursor'], 'b');
    await db.close();
  });
}
