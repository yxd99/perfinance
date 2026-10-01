import 'dart:io';

import 'package:perfinance/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens an in-memory SQLite database using the app's REAL schema
/// (createAppSchema / upgradeAppSchema), so tests cannot drift from production.
/// [fromVersion] simulates an existing DB at that version (migration path test).
Future<dynamic> openTestDatabase({int? fromVersion}) async {
  sqfliteFfiInit();
  databaseFactoryFfi.setDatabasesPath('/tmp');

  var path = inMemoryDatabasePath;
  if (fromVersion != null) {
    // Migration path: create the historic schema, then upgrade to current.
    // Needs a real file: an in-memory database is discarded when closed.
    final dir = await Directory.systemTemp.createTemp('perfinance_migration');
    path = '${dir.path}/test.db';
    final createFn = fromVersion <= 5
        ? _createV5Schema
        : fromVersion <= 7
            ? _createV7Schema
            : fromVersion <= 8
                ? _createV8Schema
                : fromVersion <= 9
                    ? _createV9Schema
                    : fromVersion <= 10
                        ? _createV10Schema
                        : _createV11Schema;
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: fromVersion,
        onCreate: (db, v) async => createFn(db),
      ),
    );
    await db.close();
  }

  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: appSchemaVersion,
      onCreate: createAppSchema,
      onUpgrade: upgradeAppSchema,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

Future<void> _createV7Schema(dynamic db) async {
  await _createBaseTables(db);
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
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableCreditCards (
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
    CREATE TABLE IF NOT EXISTS $tableAutomaticPayments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      next_run_date TEXT NOT NULL,
      payment_day_of_month INTEGER,
      frequency TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableExpenses (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      description TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tablePaymentMethods (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'other',
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

Future<void> _createV9Schema(dynamic db) async {
  await _createV8Schema(db);
  // v9 just adds note column to receivable_payments (already included in _createV8Schema)
}

Future<void> _createV10Schema(dynamic db) async {
  await _createV9Schema(db);
  // min_payment_configs was present since v1 but not included in earlier helper fns.
  // Added here so migration-from-v10 tests have a realistic starting schema.
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableMinPaymentConfigs (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL,
      amount REAL NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT,
      UNIQUE(card_id, year, month)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableMirroredDebts (
      id TEXT PRIMARY KEY,
      receivable_id TEXT NOT NULL,
      debtor_user_id TEXT NOT NULL,
      creditor_user_id TEXT NOT NULL,
      creditor_email TEXT NOT NULL,
      debtor_name TEXT,
      total_amount REAL NOT NULL,
      description TEXT,
      due_date TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      revoked_at TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableMirroredDebtPayments (
      id TEXT PRIMARY KEY,
      mirrored_debt_id TEXT NOT NULL REFERENCES $tableMirroredDebts(id) ON DELETE CASCADE,
      source_payment_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_mirrored_debts_debtor ON $tableMirroredDebts(debtor_user_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_mirrored_pay_debt ON $tableMirroredDebtPayments(mirrored_debt_id)',
  );
}

Future<void> _createV11Schema(dynamic db) async {
  await _createV10Schema(db);
  // v11 adds effective_day to min_payment_configs — already included in _createV10Schema above
  // but without the column. We need to alter the table for the "build on top" approach.
  // Since _createV10Schema creates min_payment_configs without effective_day, we add it here.
  await db.execute(
    'ALTER TABLE $tableMinPaymentConfigs ADD COLUMN effective_day INTEGER NOT NULL DEFAULT 1',
  );
}

Future<void> _createV5Schema(dynamic db) async {
  await _createBaseTables(db);
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

/// Tables that exist since v1 (plus the v2/v5 columns) and were never altered
/// until v11/v12. Every historic fixture needs them to be a realistic database.
Future<void> _createBaseTables(dynamic db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableCreditCards (
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
    CREATE TABLE IF NOT EXISTS $tablePaymentMethods (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'other',
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableExpenses (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      description TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableCardPayments (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL REFERENCES $tableCreditCards(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableMinPaymentConfigs (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL REFERENCES $tableCreditCards(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT,
      UNIQUE(card_id, year, month)
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableAutomaticPayments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      next_run_date TEXT NOT NULL,
      payment_day_of_month INTEGER,
      frequency TEXT,
      sync_status TEXT NOT NULL DEFAULT 'synced',
      updated_at TEXT,
      created_at TEXT
    )
  ''');
}
