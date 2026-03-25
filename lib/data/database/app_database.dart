import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const String _dbName = 'perfinance.db';
const int _version = 4;

const String tableCreditCards = 'credit_cards';
const String tablePaymentMethods = 'payment_methods';
const String tableExpenses = 'expenses';
const String tableCardPayments = 'card_payments';
const String tableMinPaymentConfigs = 'min_payment_configs';
const String tableDebts = 'debts';
const String tableDebtPayments = 'debt_payments';
const String tableAutomaticPayments = 'automatic_payments';

/// sync_status: synced | pending_insert | pending_update | pending_delete
const String columnSyncStatus = 'sync_status';
const String columnUpdatedAt = 'updated_at';

Future<Database> openAppDatabase(String path) async {
  return openDatabase(
    join(path, _dbName),
    version: _version,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE $tableExpenses ADD COLUMN description TEXT');
  }
  if (oldVersion < 3) {
    await db.execute('''
      CREATE TABLE $tableDebts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        number_of_installments INTEGER NOT NULL,
        due_date TEXT NOT NULL,
        $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
        $columnUpdatedAt TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableDebtPayments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
        $columnUpdatedAt TEXT,
        created_at TEXT
      )
    ''');
  }
  if (oldVersion < 4) {
    await db.execute('''
      CREATE TABLE $tableAutomaticPayments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        payment_type TEXT NOT NULL,
        payment_ref TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        next_run_date TEXT NOT NULL,
        $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
        $columnUpdatedAt TEXT,
        created_at TEXT
      )
    ''');
  }
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE $tableCreditCards (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      alias TEXT NOT NULL,
      cut_off_day INTEGER NOT NULL,
      management_fee REAL NOT NULL DEFAULT 0,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tablePaymentMethods (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'other',
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableExpenses (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      description TEXT,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableCardPayments (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableMinPaymentConfigs (
      id TEXT PRIMARY KEY,
      card_id TEXT NOT NULL,
      amount REAL NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT,
      UNIQUE(card_id, year, month)
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableDebts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      number_of_installments INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableDebtPayments (
      id TEXT PRIMARY KEY,
      debt_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableAutomaticPayments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      payment_type TEXT NOT NULL,
      payment_ref TEXT NOT NULL,
      amount REAL NOT NULL,
      description TEXT NOT NULL,
      next_run_date TEXT NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
}
