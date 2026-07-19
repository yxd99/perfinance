import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../../helpers/db_helper.dart';

CreditCard _makeCard({
  String id = 'card-1',
  String userId = 'user-1',
  String alias = 'Visa',
  int cutOffDay = 10,
  double managementFee = 0,
  bool isActive = true,
}) {
  return CreditCard(
    id: id,
    userId: userId,
    alias: alias,
    cutOffDay: cutOffDay,
    managementFee: managementFee,
    isActive: isActive,
  );
}

Future<Map<String, dynamic>> _getRow(dynamic db, String id) async {
  final rows = await db.query(tableCreditCards, where: 'id = ?', whereArgs: [id]);
  return rows.first;
}

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late CreditCardRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = CreditCardRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getAll', () {
    test('por defecto excluye is_active=false', () async {
      await repo.insert(_makeCard(id: 'c1', isActive: true));
      await repo.insert(_makeCard(id: 'c2', isActive: false));
      final results = await repo.getAll('user-1');
      expect(results.map((c) => c.id), ['c1']);
    });

    test('con includeInactive: true incluye ambas', () async {
      await repo.insert(_makeCard(id: 'c1', isActive: true));
      await repo.insert(_makeCard(id: 'c2', isActive: false));
      final results = await repo.getAll('user-1', includeInactive: true);
      expect(results.map((c) => c.id).toSet(), {'c1', 'c2'});
    });
  });

  group('insert', () {
    test('persiste is_active=true por defecto', () async {
      await repo.insert(_makeCard(id: 'c1'));
      final row = await _getRow(db, 'c1');
      expect(row['is_active'], 1);
    });
  });

  group('update', () {
    test('no toca is_active (solo el toggle dedicado la cambia)', () async {
      await repo.insert(_makeCard(id: 'c1', isActive: true));
      await repo.update(_makeCard(id: 'c1', alias: 'Visa Gold', isActive: false));
      final row = await _getRow(db, 'c1');
      // isActive: false pasado a update() no debe aplicarse — solo setActive lo cambia
      expect(row['is_active'], 1);
      expect(row['alias'], 'Visa Gold');
    });
  });

  group('upsertFromRemote', () {
    test('respeta is_active remoto (no lo resetea a default)', () async {
      await repo.upsertFromRemote(_makeCard(id: 'c1', isActive: false));
      final row = await _getRow(db, 'c1');
      expect(row['is_active'], 0);
    });
  });

  group('setActive', () {
    test('setActive(cardId, false) marca is_active=0 y sync_status=pending_update', () async {
      await repo.insert(_makeCard(id: 'c1', isActive: true));
      await db.update(tableCreditCards, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['c1']);
      await repo.setActive('c1', false);
      final row = await _getRow(db, 'c1');
      expect(row['is_active'], 0);
      expect(row[columnSyncStatus], 'pending_update');
    });

    test('setActive(cardId, true) marca is_active=1 y sync_status=pending_update', () async {
      await repo.insert(_makeCard(id: 'c1', isActive: false));
      await db.update(tableCreditCards, {columnSyncStatus: 'synced'},
          where: 'id = ?', whereArgs: ['c1']);
      await repo.setActive('c1', true);
      final row = await _getRow(db, 'c1');
      expect(row['is_active'], 1);
      expect(row[columnSyncStatus], 'pending_update');
    });
  });
}
