import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens an in-memory SQLite database using the app's schema (onCreate + onUpgrade).
/// [fromVersion] simulates an existing DB at that version (migration path test).
Future<dynamic> openTestDatabase({int? fromVersion}) async {
  sqfliteFfiInit();
  databaseFactoryFfi.setDatabasesPath('/tmp');

  if (fromVersion == null) {
    return databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, v) async => _createV8Schema(db),
      ),
    );
  }

  // Migration path: open at fromVersion, then upgrade to current.
  final createFn =
      fromVersion <= 5 ? _createV5Schema : _createV7Schema;
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: fromVersion,
      onCreate: (db, v) async => createFn(db),
    ),
  );
  await db.close();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 9,
      onCreate: (db, v) async => _createV8Schema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await db.transaction((txn) async {
            await txn.execute(
              "ALTER TABLE $tableDebts ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
            );
            await txn.execute('''
              UPDATE $tableDebts
              SET status = 'paid'
              WHERE id IN (
                SELECT dp.debt_id
                FROM $tableDebtPayments dp
                GROUP BY dp.debt_id
                HAVING SUM(dp.amount) >= (
                  SELECT d2.total_amount FROM $tableDebts d2 WHERE d2.id = dp.debt_id
                )
              )
            ''');
          });
        }
        if (oldVersion < 8) {
          await db.transaction((txn) async {
            await txn.execute('''
              CREATE TABLE $tableReceivables (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                debtor_name TEXT NOT NULL,
                debtor_email TEXT,
                total_amount REAL NOT NULL,
                description TEXT,
                due_date TEXT,
                status TEXT NOT NULL DEFAULT 'active',
                sync_status TEXT NOT NULL DEFAULT 'synced',
                updated_at TEXT,
                created_at TEXT
              )
            ''');
            await txn.execute('''
              CREATE TABLE $tableReceivablePayments (
                id TEXT PRIMARY KEY,
                receivable_id TEXT NOT NULL REFERENCES $tableReceivables(id) ON DELETE CASCADE,
                amount REAL NOT NULL,
                date TEXT NOT NULL,
                note TEXT,
                sync_status TEXT NOT NULL DEFAULT 'synced',
                updated_at TEXT,
                created_at TEXT
              )
            ''');
            await txn.execute(
              'CREATE INDEX idx_receivables_user ON $tableReceivables(user_id)',
            );
            await txn.execute(
              'CREATE INDEX idx_recv_payments_recv ON $tableReceivablePayments(receivable_id)',
            );
            await txn.execute(
              'CREATE INDEX idx_recv_payments_sync ON $tableReceivablePayments(sync_status)',
            );
          });
        }
        if (oldVersion < 9) {
          final cols = await db.rawQuery(
            'PRAGMA table_info($tableReceivablePayments)',
          ) as List<Map<String, dynamic>>;
          if (!cols.any((c) => c['name'] == 'note')) {
            await db.execute(
              'ALTER TABLE $tableReceivablePayments ADD COLUMN note TEXT',
            );
          }
        }
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

Future<void> _createV7Schema(dynamic db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableDebts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      number_of_installments INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableDebtPayments (
      id TEXT PRIMARY KEY,
      debt_id TEXT NOT NULL REFERENCES $tableDebts(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
}

Future<void> _createV8Schema(dynamic db) async {
  await _createV7Schema(db);
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableReceivables (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      debtor_name TEXT NOT NULL,
      debtor_email TEXT,
      total_amount REAL NOT NULL,
      description TEXT,
      due_date TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableReceivablePayments (
      id TEXT PRIMARY KEY,
      receivable_id TEXT NOT NULL REFERENCES $tableReceivables(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_receivables_user ON $tableReceivables(user_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_recv_payments_recv ON $tableReceivablePayments(receivable_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_recv_payments_sync ON $tableReceivablePayments(sync_status)',
  );
}

Future<void> _createV5Schema(dynamic db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableDebts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      number_of_installments INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableDebtPayments (
      id TEXT PRIMARY KEY,
      debt_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
}
