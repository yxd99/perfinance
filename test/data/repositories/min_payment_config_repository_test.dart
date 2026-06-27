// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

// ── helpers ─────────────────────────────────────────────────────────────────

final _uuid = Uuid();

Future<dynamic> _openDb() async {
  sqfliteFfiInit();
  databaseFactoryFfi.setDatabasesPath('/tmp');
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE $tableCreditCards (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            alias TEXT NOT NULL,
            cut_off_day INTEGER NOT NULL,
            management_fee REAL NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            updated_at TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $tableMinPaymentConfigs (
            id TEXT PRIMARY KEY,
            card_id TEXT NOT NULL REFERENCES $tableCreditCards(id) ON DELETE CASCADE,
            amount REAL NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            effective_day INTEGER NOT NULL DEFAULT 1,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            updated_at TEXT,
            created_at TEXT,
            UNIQUE(card_id, year, month)
          )
        ''');
      },
    ),
  );
}

Future<void> _insertCard(dynamic db, {String id = 'card-1'}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableCreditCards, {
    'id': id,
    'user_id': 'user-1',
    'alias': 'Test',
    'cut_off_day': 15,
    'management_fee': 0.0,
    'sync_status': 'synced',
    'updated_at': now,
    'created_at': now,
  });
}

MinPaymentConfig _makeConfig({
  String id = '',
  String cardId = 'card-1',
  double amount = 500.0,
  int year = 2026,
  int month = 6,
  int effectiveDay = 10,
}) {
  return MinPaymentConfig(
    id: id.isEmpty ? _uuid.v4() : id,
    cardId: cardId,
    amount: amount,
    year: year,
    month: month,
    effectiveDay: effectiveDay,
  );
}

Future<Map<String, dynamic>> _getRow(dynamic db, String id) async {
  final rows = await db.query(
    tableMinPaymentConfigs,
    where: 'id = ?',
    whereArgs: [id],
  ) as List<Map<String, dynamic>>;
  return rows.first;
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  late dynamic db;
  late MinPaymentConfigRepository repo;

  setUp(() async {
    db = await _openDb();
    await _insertCard(db);
    repo = MinPaymentConfigRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Task 3.1 ────────────────────────────────────────────────────────────────

  group('insert() — ConflictAlgorithm.ignore (Task 3.1)', () {
    test('insert ignores duplicate (cardId, year, month) without throwing', () async {
      final first = _makeConfig(id: 'cfg-1', effectiveDay: 10, amount: 500.0);
      await repo.insert(first);

      // Second insert with same (cardId, year, month) but different effectiveDay + amount
      final second = _makeConfig(id: 'cfg-2', effectiveDay: 20, amount: 999.0);
      // Must NOT throw
      await expectLater(repo.insert(second), completes);

      // The first row should be unchanged
      final row = await _getRow(db, 'cfg-1');
      expect(row['effective_day'], equals(10));
      expect(row['amount'], equals(500.0));
    });

    test('insert stores effectiveDay in the row', () async {
      final cfg = _makeConfig(id: 'cfg-ed', effectiveDay: 15);
      await repo.insert(cfg);

      final row = await _getRow(db, 'cfg-ed');
      expect(row['effective_day'], equals(15));
    });

    test('duplicate insert does not overwrite effectiveDay of existing row', () async {
      final first = _makeConfig(id: 'cfg-prot', effectiveDay: 7, amount: 400.0);
      await repo.insert(first);

      // Attempt second insert with same (cardId, year, month)
      final second = _makeConfig(id: 'cfg-prot2', effectiveDay: 28, amount: 800.0);
      await repo.insert(second);

      // First row must still have effectiveDay=7
      final row = await _getRow(db, 'cfg-prot');
      expect(row['effective_day'], equals(7),
          reason: 'effectiveDay must not be overwritten by duplicate insert');
    });
  });

  // ── Task 3.2 ────────────────────────────────────────────────────────────────

  group('update() — amount only, effectiveDay unchanged (Task 3.2)', () {
    test('update only changes amount, effectiveDay remains unchanged', () async {
      final cfg = _makeConfig(id: 'cfg-upd', effectiveDay: 12, amount: 600.0);
      await repo.insert(cfg);

      // Update with different amount (effectiveDay is ignored in update)
      await repo.update(MinPaymentConfig(
        id: 'cfg-upd',
        cardId: cfg.cardId,
        amount: 900.0,
        year: cfg.year,
        month: cfg.month,
        effectiveDay: 25, // This should NOT be written
      ));

      final row = await _getRow(db, 'cfg-upd');
      expect(row['amount'], equals(900.0));
      expect(row['effective_day'], equals(12),
          reason: 'effectiveDay must not change after update()');
    });

    test('update sets sync_status to pending_update', () async {
      final cfg = _makeConfig(id: 'cfg-sync');
      await repo.insert(cfg);

      await repo.update(MinPaymentConfig(
        id: 'cfg-sync',
        cardId: cfg.cardId,
        amount: 750.0,
        year: cfg.year,
        month: cfg.month,
      ));

      final row = await _getRow(db, 'cfg-sync');
      expect(row['sync_status'], equals('pending_update'));
    });
  });

  // ── Task 3.3 ────────────────────────────────────────────────────────────────

  group('upsertFromRemote() — stores effectiveDay (Task 3.3)', () {
    test('upsertFromRemote stores effective_day from remote payload', () async {
      final remote = _makeConfig(id: 'cfg-remote', effectiveDay: 20, amount: 1000.0);
      await repo.upsertFromRemote(remote);

      final row = await _getRow(db, 'cfg-remote');
      expect(row['effective_day'], equals(20));
      expect(row['amount'], equals(1000.0));
      expect(row['sync_status'], equals('synced'));
    });

    test('upsertFromRemote overwrites existing synced row with remote effectiveDay', () async {
      // Insert local synced row
      final local = _makeConfig(id: 'cfg-over', effectiveDay: 5, amount: 300.0);
      await repo.insert(local);
      await repo.markSynced('cfg-over');

      // Remote upsert with different effectiveDay
      final remote = MinPaymentConfig(
        id: 'cfg-over',
        cardId: local.cardId,
        amount: 500.0,
        year: local.year,
        month: local.month,
        effectiveDay: 18,
        syncStatus: 'synced',
      );
      await repo.upsertFromRemote(remote);

      final row = await _getRow(db, 'cfg-over');
      expect(row['effective_day'], equals(18),
          reason: 'remote upsert must overwrite effectiveDay for synced rows');
    });

    test('upsertFromRemote does NOT overwrite pending_update row', () async {
      // Insert and mark as pending_update (local change not yet synced)
      final local = _makeConfig(id: 'cfg-pending', effectiveDay: 3, amount: 200.0);
      await repo.insert(local);
      await repo.update(MinPaymentConfig(
        id: 'cfg-pending',
        cardId: local.cardId,
        amount: 250.0,
        year: local.year,
        month: local.month,
      ));

      // Remote upsert — must be skipped for pending rows
      final remote = MinPaymentConfig(
        id: 'cfg-pending',
        cardId: local.cardId,
        amount: 999.0,
        year: local.year,
        month: local.month,
        effectiveDay: 28,
        syncStatus: 'synced',
      );
      await repo.upsertFromRemote(remote);

      final row = await _getRow(db, 'cfg-pending');
      expect(row['amount'], equals(250.0),
          reason: 'pending_update row must not be overwritten by remote');
      expect(row['effective_day'], equals(3));
    });
  });

  // ── getForCardAndMonth ───────────────────────────────────────────────────────

  group('getForCardAndMonth()', () {
    test('returns null when no config exists', () async {
      final result = await repo.getForCardAndMonth('card-1', 2026, 6);
      expect(result, isNull);
    });

    test('returns config with correct effectiveDay', () async {
      final cfg = _makeConfig(id: 'cfg-get', effectiveDay: 17);
      await repo.insert(cfg);

      final result = await repo.getForCardAndMonth('card-1', 2026, 6);
      expect(result, isNotNull);
      expect(result!.effectiveDay, equals(17));
    });
  });
}
