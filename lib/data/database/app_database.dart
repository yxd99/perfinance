import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const String _dbName = 'perfinance.db';
const int _version = 12;

const String tableCreditCards = 'credit_cards';
const String tablePaymentMethods = 'payment_methods';
const String tableExpenses = 'expenses';
const String tableCardPayments = 'card_payments';
const String tableMinPaymentConfigs = 'min_payment_configs';
const String tableDebts = 'debts';
const String tableDebtPayments = 'debt_payments';
const String tableAutomaticPayments = 'automatic_payments';
const String tableReceivables = 'receivables';
const String tableReceivablePayments = 'receivable_payments';
const String tableMirroredDebts = 'mirrored_debts';
const String tableMirroredDebtPayments = 'mirrored_debt_payments';

/// sync_status: synced | pending_insert | pending_update | pending_delete
const String columnSyncStatus = 'sync_status';
const String columnUpdatedAt = 'updated_at';

Future<Database> openAppDatabase(String path) async {
  return openDatabase(
    join(path, _dbName),
    version: _version,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onOpen: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE $tableExpenses ADD COLUMN description TEXT');
    });
  }
  if (oldVersion < 3) {
    await db.transaction((txn) async {
      await txn.execute('''
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
      await txn.execute('''
        CREATE TABLE $tableDebtPayments (
          id TEXT PRIMARY KEY,
          debt_id TEXT NOT NULL REFERENCES $tableDebts(id) ON DELETE CASCADE,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
          $columnUpdatedAt TEXT,
          created_at TEXT
        )
      ''');
    });
  }
  if (oldVersion < 4) {
    await db.transaction((txn) async {
      await txn.execute('''
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
    });
  }
  if (oldVersion < 5) {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE $tableAutomaticPayments ADD COLUMN payment_day_of_month INTEGER',
      );
      await txn.execute(
        "ALTER TABLE $tableAutomaticPayments ADD COLUMN frequency TEXT",
      );
      await txn.execute(
        "UPDATE $tableAutomaticPayments SET payment_day_of_month = CAST(strftime('%d', next_run_date) AS INTEGER), frequency = 'mensual' WHERE payment_day_of_month IS NULL",
      );
    });
  }
  if (oldVersion < 6) {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE $tableDebts ADD COLUMN manually_closed_at TEXT');
    });
  }
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
          $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
          $columnUpdatedAt TEXT,
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
          $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
          $columnUpdatedAt TEXT,
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
        'CREATE INDEX idx_recv_payments_sync ON $tableReceivablePayments($columnSyncStatus)',
      );
    });
  }
  if (oldVersion < 9) {
    // Adds note column if missing — users whose v8 was created before the fix.
    final cols = await db.rawQuery(
      'PRAGMA table_info($tableReceivablePayments)',
    ) as List<Map<String, dynamic>>;
    if (!cols.any((c) => c['name'] == 'note')) {
      await db.execute(
        'ALTER TABLE $tableReceivablePayments ADD COLUMN note TEXT',
      );
    }
  }
  if (oldVersion < 10) {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE $tableMirroredDebts (
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
          $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
          $columnUpdatedAt TEXT,
          created_at TEXT
        )
      ''');
      await txn.execute('''
        CREATE TABLE $tableMirroredDebtPayments (
          id TEXT PRIMARY KEY,
          mirrored_debt_id TEXT NOT NULL REFERENCES $tableMirroredDebts(id) ON DELETE CASCADE,
          source_payment_id TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
          $columnUpdatedAt TEXT,
          created_at TEXT
        )
      ''');
      await txn.execute(
        'CREATE INDEX idx_mirrored_debts_debtor ON $tableMirroredDebts(debtor_user_id)',
      );
      await txn.execute(
        'CREATE INDEX idx_mirrored_pay_debt ON $tableMirroredDebtPayments(mirrored_debt_id)',
      );
    });
  }
  if (oldVersion < 11) {
    await db.execute(
      'ALTER TABLE $tableMinPaymentConfigs ADD COLUMN effective_day INTEGER NOT NULL DEFAULT 1',
    );
  }
  if (oldVersion < 12) {
    await db.execute(
      'ALTER TABLE $tableCreditCards ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      "ALTER TABLE $tableAutomaticPayments ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
    );
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
      is_active INTEGER NOT NULL DEFAULT 1,
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
      card_id TEXT NOT NULL REFERENCES $tableCreditCards(id) ON DELETE CASCADE,
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
      card_id TEXT NOT NULL REFERENCES $tableCreditCards(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      year INTEGER NOT NULL,
      month INTEGER NOT NULL,
      effective_day INTEGER NOT NULL DEFAULT 1,
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
      status TEXT NOT NULL DEFAULT 'active',
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
      payment_day_of_month INTEGER,
      frequency TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableReceivables (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      debtor_name TEXT NOT NULL,
      debtor_email TEXT,
      total_amount REAL NOT NULL,
      description TEXT,
      due_date TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableReceivablePayments (
      id TEXT PRIMARY KEY,
      receivable_id TEXT NOT NULL REFERENCES $tableReceivables(id) ON DELETE CASCADE,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_receivables_user ON $tableReceivables(user_id)',
  );
  await db.execute(
    'CREATE INDEX idx_recv_payments_recv ON $tableReceivablePayments(receivable_id)',
  );
  await db.execute(
    'CREATE INDEX idx_recv_payments_sync ON $tableReceivablePayments($columnSyncStatus)',
  );
  await db.execute('''
    CREATE TABLE $tableMirroredDebts (
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
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableMirroredDebtPayments (
      id TEXT PRIMARY KEY,
      mirrored_debt_id TEXT NOT NULL REFERENCES $tableMirroredDebts(id) ON DELETE CASCADE,
      source_payment_id TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      $columnSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $columnUpdatedAt TEXT,
      created_at TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_mirrored_debts_debtor ON $tableMirroredDebts(debtor_user_id)',
  );
  await db.execute(
    'CREATE INDEX idx_mirrored_pay_debt ON $tableMirroredDebtPayments(mirrored_debt_id)',
  );
}
