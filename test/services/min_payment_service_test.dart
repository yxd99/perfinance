// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/services/min_payment_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';


const _cardId = 'card-1';
const _userId = 'user-1';
final _uuid = Uuid();

Future<void> _insertCreditCard(dynamic db) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableCreditCards, {
    'id': _cardId,
    'user_id': _userId,
    'alias': 'Test Card',
    'cut_off_day': 15,
    'management_fee': 0.0,
    'sync_status': 'synced',
    'updated_at': now,
    'created_at': now,
  });
}

Future<void> _insertConfig(dynamic db, MinPaymentConfig c) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableMinPaymentConfigs, {
    'id': c.id,
    'card_id': c.cardId,
    'amount': c.amount,
    'year': c.year,
    'month': c.month,
    'effective_day': c.effectiveDay,
    'sync_status': c.syncStatus,
    'updated_at': c.updatedAt ?? now,
    'created_at': c.createdAt ?? now,
  });
}

Future<void> _insertPayment(dynamic db, CardPayment p) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(tableCardPayments, {
    'id': p.id,
    'card_id': p.cardId,
    'amount': p.amount,
    'date': p.date.toIso8601String(),
    'sync_status': 'synced',
    'updated_at': now,
    'created_at': now,
  });
}

MinPaymentConfig _config({
  int effectiveDay = 1,
  double amount = 1000.0,
  int? year,
  int? month,
}) {
  final now = DateTime.now();
  return MinPaymentConfig(
    id: _uuid.v4(),
    cardId: _cardId,
    amount: amount,
    year: year ?? now.year,
    month: month ?? now.month,
    effectiveDay: effectiveDay,
  );
}

CardPayment _payment(DateTime date, double amount) => CardPayment(
      id: _uuid.v4(),
      cardId: _cardId,
      amount: amount,
      date: date,
    );

void main() {
  sqfliteFfiInit();

  late dynamic db;
  late MinPaymentConfigRepository configRepo;
  late CardPaymentRepository paymentRepo;

  setUp(() async {
    // Use a minimal in-memory DB with only the tables needed for these tests.
    sqfliteFfiInit();
    databaseFactoryFfi.setDatabasesPath('/tmp');
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
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
    await _insertCreditCard(db);
    configRepo = MinPaymentConfigRepository(null, dbOverride: db);
    paymentRepo = CardPaymentRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MinPaymentStatus fields', () {
    test('MinPaymentStatus exposes totalPaidMonth', () {
      final status = MinPaymentStatus(
        configured: 1000.0,
        paid: 600.0,
        totalPaidMonth: 800.0,
        pending: 400.0,
      );
      expect(status.totalPaidMonth, equals(800.0));
    });

    test('isUpToDate when pending <= 0', () {
      final status = MinPaymentStatus(
        configured: 500.0,
        paid: 600.0,
        totalPaidMonth: 600.0,
        pending: 0.0,
      );
      expect(status.isUpToDate, isTrue);
    });
  });

  group('getStatus()', () {
    test('returns null when no config found', () async {
      final result = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );
      expect(result, isNull);
    });

    test('totalPaidMonth includes payments before effectiveDay', () async {
      final now = DateTime.now();
      final cfg = _config(effectiveDay: 10, amount: 1000.0);
      await _insertConfig(db, cfg);
      // Payment on day 5 — before effectiveDay=10
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 5), 200.0));
      // Payment on day 15 — on or after effectiveDay=10
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 15), 300.0));

      final status = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );

      expect(status, isNotNull);
      expect(status!.totalPaidMonth, equals(500.0),
          reason: 'totalPaidMonth must include ALL payments');
      expect(status.paid, equals(300.0),
          reason: 'paid must only include payments >= effectiveDay cutoff');
    });

    test('payment exactly on effectiveDay midnight counts in paid', () async {
      final now = DateTime.now();
      final cfg = _config(effectiveDay: 10, amount: 1000.0);
      await _insertConfig(db, cfg);
      // Exactly midnight on day 10 — inclusive boundary (>=)
      await _insertPayment(
        db,
        _payment(DateTime(now.year, now.month, 10, 0, 0, 0), 400.0),
      );

      final status = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );

      expect(status!.paid, equals(400.0),
          reason: 'payment exactly at cutoff midnight must count in paid');
      expect(status.totalPaidMonth, equals(400.0));
    });

    test('payment one millisecond before effectiveDay midnight does NOT count in paid', () async {
      final now = DateTime.now();
      final cfg = _config(effectiveDay: 10, amount: 1000.0);
      await _insertConfig(db, cfg);
      // 1ms before midnight on day 10 = 23:59:59.999 on day 9
      final justBefore = DateTime(now.year, now.month, 10, 0, 0, 0)
          .subtract(const Duration(milliseconds: 1));
      await _insertPayment(db, _payment(justBefore, 250.0));

      final status = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );

      expect(status!.paid, equals(0.0),
          reason: 'payment 1ms before cutoff must NOT count in paid');
      expect(status.totalPaidMonth, equals(250.0),
          reason: 'but must count in totalPaidMonth');
    });

    test('effectiveDay 1 makes paid equal totalPaidMonth', () async {
      final now = DateTime.now();
      final cfg = _config(effectiveDay: 1, amount: 1000.0);
      await _insertConfig(db, cfg);
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 3), 100.0));
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 10), 200.0));
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 22), 300.0));

      final status = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );

      expect(status!.paid, equals(status.totalPaidMonth),
          reason: 'effectiveDay=1: all month payments count toward paid');
      expect(status.paid, equals(600.0));
    });

    test('pending derives from paid, not from totalPaidMonth', () async {
      final now = DateTime.now();
      final cfg = _config(effectiveDay: 15, amount: 1000.0);
      await _insertConfig(db, cfg);
      // Payment before cutoff — counts in totalPaid but NOT in paid
      await _insertPayment(db, _payment(DateTime(now.year, now.month, 5), 300.0));

      final status = await MinPaymentService.getStatus(
        configRepo,
        paymentRepo,
        _cardId,
      );

      expect(status!.totalPaidMonth, equals(300.0));
      expect(status.paid, equals(0.0));
      // pending = configured - paid = 1000 - 0 = 1000
      expect(status.pending, equals(1000.0),
          reason: 'pending must derive from paid, not totalPaidMonth');
    });
  });
}
