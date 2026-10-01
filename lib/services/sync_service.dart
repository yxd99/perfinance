import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/repositories/debt_payment_repository.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/data/repositories/automatic_payment_repository.dart';
import 'package:perfinance/data/repositories/expense_repository.dart';
import 'package:perfinance/data/repositories/min_payment_config_repository.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/data/repositories/receivable_payment_repository.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';
import 'package:perfinance/data/repositories/mirrored_debt_repository.dart';
import 'package:perfinance/features/auth/auth_service.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:perfinance/features/expenses/expenses_provider.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

const String _keyLastSync = 'perfinance_last_sync';

final isSyncingProvider = StateProvider<bool>((ref) => false);

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  SyncService(this._ref);
  final Ref _ref;
  bool _isSyncing = false;

  Future<String?> get _userId async => _ref.read(authServiceProvider).userId;
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<DateTime?> getLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyLastSync);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  Future<void> setLastSync(DateTime t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, t.toIso8601String());
  }

  /// Elimina la preferencia de última sincronización (p. ej. al hacer logout).
  Future<void> clearLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSync);
  }

  /// Cierra la base SQLite, elimina el archivo local y limpia last sync. Llamar antes de signOut.
  Future<void> clearLocalDataOnLogout() async {
    final db = await _ref.read(databaseProvider.future);
    final path = db.path;
    await db.close();
    _ref.invalidate(databaseProvider);
    final file = File(path);
    if (await file.exists()) await file.delete();
    await clearLastSync();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _ref.read(isSyncingProvider.notifier).state = true;
    try {
      await _syncInternal();
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'sync.full');
      rethrow;
    } finally {
      _isSyncing = false;
      _ref.read(isSyncingProvider.notifier).state = false;
    }
  }

  /// Push pending local records to Supabase without pulling remote changes.
  /// Call this after any local write when online.
  /// Does NOT set isSyncingProvider — background pushes should not show the banner.
  Future<void> pushPendingIfOnline() async {
    if (_isSyncing) return;
    final list = await Connectivity().checkConnectivity();
    final offline = list.isNotEmpty && list.every((r) => r == ConnectivityResult.none);
    if (offline) return;
    final userId = await _userId;
    if (userId == null) return;
    _isSyncing = true;
    try {
      await _push(userId);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncInternal() async {
    final userId = await _userId;
    if (userId == null) return;

    await _push(userId);
    await _pull(userId);
    await setLastSync(DateTime.now());

    _ref.invalidate(expensesListProvider);
    _ref.invalidate(creditCardsListProvider);
    _ref.invalidate(debtsListProvider);
    _ref.invalidate(paymentMethodsListProvider);
    _ref.invalidate(automaticPaymentsListProvider);
    _ref.invalidate(receivablesListProvider);
    _ref.invalidate(dashboardDebtProvider);
    _ref.invalidate(dashboardUsageProvider);
    _ref.invalidate(dashboardComparisonProvider);
    _ref.invalidate(dashboardAutomaticPaymentsSummaryProvider);
  }

  void _reportPushError(
    Object error,
    StackTrace stackTrace,
    String table,
    String recordId,
    String syncStatus,
  ) {
    ErrorReporter.capture(
      error,
      stackTrace,
      operation: 'sync.push',
      details: {'table': table, 'record_id': recordId, 'sync_status': syncStatus},
    );
  }

  Future<void> _push(String userId) async {
    final ccRepo = _ref.read(creditCardRepositoryProvider);
    final pmRepo = _ref.read(paymentMethodRepositoryProvider);
    final expRepo = _ref.read(expenseRepositoryProvider);
    final payRepo = _ref.read(cardPaymentRepositoryProvider);
    final minRepo = _ref.read(minPaymentConfigRepositoryProvider);

    final debtRepo = _ref.read(debtRepositoryProvider);
    final debtPayRepo = _ref.read(debtPaymentRepositoryProvider);
    final autoPayRepo = _ref.read(automaticPaymentRepositoryProvider);
    final receivableRepo = _ref.read(receivableRepositoryProvider);
    final receivablePayRepo = _ref.read(receivablePaymentRepositoryProvider);

    final ccTable = _supabase.from('credit_cards');
    final pmTable = _supabase.from('payment_methods');
    final expTable = _supabase.from('expenses');
    final payTable = _supabase.from('card_payments');
    final minTable = _supabase.from('min_payment_configs');
    final debtsTable = _supabase.from('debts');
    final debtPaymentsTable = _supabase.from('debt_payments');
    final automaticPaymentsTable = _supabase.from('automatic_payments');
    final receivablesTable = _supabase.from('receivables');
    final receivablePaymentsTable = _supabase.from('receivable_payments');

    for (final c in await ccRepo.getPendingForPush(userId)) {
      try {
        if (c.syncStatus == 'pending_delete') {
          await ccTable.delete().eq('id', c.id);
          await ccRepo.deleteLocal(c.id);
        } else if (c.syncStatus == 'pending_insert') {
          await ccTable.upsert(_toRemoteCard(c), onConflict: 'id');
        } else {
          await ccTable.upsert(_toRemoteCard(c), onConflict: 'id');
        }
        if (c.syncStatus != 'pending_delete') await ccRepo.markSynced(c.id);
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'credit_cards', c.id, c.syncStatus);
      }
    }

    for (final p in await pmRepo.getPendingForPush(userId)) {
      try {
        if (p.syncStatus == 'pending_delete') {
          await pmTable.delete().eq('id', p.id);
          await pmRepo.deleteLocal(p.id);
        } else if (p.syncStatus == 'pending_insert') {
          await pmTable.upsert(_toRemotePaymentMethod(p), onConflict: 'id');
        } else {
          await pmTable.upsert(_toRemotePaymentMethod(p), onConflict: 'id');
        }
        if (p.syncStatus != 'pending_delete') await pmRepo.markSynced(p.id);
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'payment_methods', p.id, p.syncStatus);
      }
    }

    for (final e in await expRepo.getPendingForPush(userId)) {
      try {
        if (e.syncStatus == 'pending_delete') {
          await expTable.delete().eq('id', e.id);
          await expRepo.deleteLocal(e.id);
        } else if (e.syncStatus == 'pending_insert') {
          await expTable.upsert(_toRemoteExpense(e), onConflict: 'id');
        } else if (e.syncStatus == 'pending_update') {
          await expTable.upsert(_toRemoteExpense(e), onConflict: 'id');
        }
        if (e.syncStatus != 'pending_delete') await expRepo.markSynced(e.id);
      } catch (err, st) {
        if (err is AuthException) rethrow;
        _reportPushError(err, st, 'expenses', e.id, e.syncStatus);
      }
    }

    for (final p in await payRepo.getPendingForPush()) {
      try {
        if (p.syncStatus == 'pending_delete') {
          await payTable.delete().eq('id', p.id);
          await payRepo.deleteLocal(p.id);
        } else if (p.syncStatus == 'pending_insert' || p.syncStatus == 'pending_update') {
          await payTable.upsert(_toRemoteCardPayment(p), onConflict: 'id');
          await payRepo.markSynced(p.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'card_payments', p.id, p.syncStatus);
      }
    }

    for (final m in await minRepo.getPendingForPush()) {
      try {
        if (m.syncStatus == 'pending_insert' || m.syncStatus == 'pending_update') {
          await minTable.upsert(_toRemoteMinConfig(m), onConflict: 'id');
          await minRepo.markSynced(m.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'min_payment_configs', m.id, m.syncStatus);
      }
    }

    for (final d in await debtRepo.getPendingForPush(userId)) {
      try {
        if (d.syncStatus == 'pending_delete') {
          await debtsTable.delete().eq('id', d.id);
          await debtRepo.deleteLocal(d.id);
        } else if (d.syncStatus == 'pending_insert') {
          await debtsTable.upsert(_toRemoteDebt(d), onConflict: 'id');
        } else {
          await debtsTable.upsert(_toRemoteDebt(d), onConflict: 'id');
        }
        if (d.syncStatus != 'pending_delete') await debtRepo.markSynced(d.id);
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'debts', d.id, d.syncStatus);
      }
    }

    for (final p in await debtPayRepo.getPendingForPush()) {
      try {
        if (p.syncStatus == 'pending_delete') {
          await debtPaymentsTable.delete().eq('id', p.id);
          await debtPayRepo.deleteLocal(p.id);
        } else if (p.syncStatus == 'pending_insert') {
          await debtPaymentsTable.upsert(_toRemoteDebtPayment(p), onConflict: 'id');
          await debtPayRepo.markSynced(p.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'debt_payments', p.id, p.syncStatus);
      }
    }

    for (final a in await autoPayRepo.getPendingForPush(userId)) {
      try {
        if (a.syncStatus == 'pending_delete') {
          await automaticPaymentsTable.delete().eq('id', a.id);
          await autoPayRepo.deleteLocal(a.id);
        } else if (a.syncStatus == 'pending_insert') {
          await automaticPaymentsTable.upsert(_toRemoteAutomaticPayment(a), onConflict: 'id');
          await autoPayRepo.markSynced(a.id);
        } else {
          await automaticPaymentsTable.upsert(_toRemoteAutomaticPayment(a), onConflict: 'id');
          await autoPayRepo.markSynced(a.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'automatic_payments', a.id, a.syncStatus);
      }
    }

    for (final r in await receivableRepo.getPendingForPush(userId)) {
      try {
        if (r.syncStatus == 'pending_delete') {
          await receivablesTable.delete().eq('id', r.id);
          await receivableRepo.deleteLocal(r.id);
        } else if (r.syncStatus == 'pending_insert') {
          await receivablesTable.upsert(_toRemoteReceivable(r), onConflict: 'id');
          await receivableRepo.markSynced(r.id);
        } else if (r.syncStatus == 'pending_update') {
          await receivablesTable.upsert(_toRemoteReceivable(r), onConflict: 'id');
          await receivableRepo.markSynced(r.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'receivables', r.id, r.syncStatus);
      }
    }

    for (final p in await receivablePayRepo.getPendingForPush()) {
      try {
        if (p.syncStatus == 'pending_delete') {
          await receivablePaymentsTable.delete().eq('id', p.id);
          await receivablePayRepo.deleteLocal(p.id);
        } else if (p.syncStatus == 'pending_insert') {
          await receivablePaymentsTable.upsert(_toRemoteReceivablePayment(p), onConflict: 'id');
          await receivablePayRepo.markSynced(p.id);
        } else if (p.syncStatus == 'pending_update') {
          await receivablePaymentsTable.upsert(_toRemoteReceivablePayment(p), onConflict: 'id');
          await receivablePayRepo.markSynced(p.id);
        }
      } catch (e, st) {
        if (e is AuthException) rethrow;
        _reportPushError(e, st, 'receivable_payments', p.id, p.syncStatus);
      }
    }
  }

  Future<void> _pull(String userId) async {
    final ccRepo = _ref.read(creditCardRepositoryProvider);
    final pmRepo = _ref.read(paymentMethodRepositoryProvider);
    final expRepo = _ref.read(expenseRepositoryProvider);
    final payRepo = _ref.read(cardPaymentRepositoryProvider);
    final minRepo = _ref.read(minPaymentConfigRepositoryProvider);
    final debtRepo = _ref.read(debtRepositoryProvider);
    final debtPayRepo = _ref.read(debtPaymentRepositoryProvider);
    final autoPayRepo = _ref.read(automaticPaymentRepositoryProvider);
    final receivableRepo = _ref.read(receivableRepositoryProvider);
    final receivablePayRepo = _ref.read(receivablePaymentRepositoryProvider);

    final ccRes = await _supabase.from('credit_cards').select().eq('user_id', userId);
    for (final row in ccRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final card = CreditCard(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        alias: map['alias'] as String,
        cutOffDay: map['cut_off_day'] as int,
        managementFee: (map['management_fee'] as num).toDouble(),
        isActive: (map['is_active'] as bool?) ?? true,
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
      );
      await ccRepo.upsertFromRemote(card);
    }

    final pmRes = await _supabase.from('payment_methods').select().eq('user_id', userId);
    for (final row in pmRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final pm = PaymentMethod(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        type: map['type'] as String? ?? 'other',
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
      );
      await pmRepo.upsertFromRemote(pm);
    }

    final expRes = await _supabase.from('expenses').select().eq('user_id', userId);
    final remoteExpenseIds = <String>{};
    for (final row in expRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String;
      remoteExpenseIds.add(id);
      final e = Expense(
        id: id,
        userId: map['user_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: parseDateOnly(map['date'] as String),
        paymentType: map['payment_type'] as String,
        paymentRef: map['payment_ref'] as String,
        description: map['description'] as String?,
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
      );
      await expRepo.upsertFromRemote(e);
    }
    // Re-encolar gastos locales synced que no existen en Supabase (ghost expenses).
    await expRepo.requeueOrphansAsPendingInsert(remoteExpenseIds, userId);

    final cardIds = (await ccRepo.getAll(userId, includeInactive: true)).map((c) => c.id).toList();
    for (final cardId in cardIds) {
      final payRes = await _supabase.from('card_payments').select().eq('card_id', cardId);
      for (final row in payRes as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final p = CardPayment(
          id: map['id'] as String,
          cardId: map['card_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          date: parseDateOnly(map['date'] as String),
          syncStatus: 'synced',
          updatedAt: map['updated_at']?.toString(),
          createdAt: map['created_at']?.toString(),
        );
        await payRepo.upsertFromRemote(p);
      }
    }

    for (final cardId in cardIds) {
      final minRes = await _supabase.from('min_payment_configs').select().eq('card_id', cardId);
      for (final row in minRes as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final m = MinPaymentConfig(
          id: map['id'] as String,
          cardId: map['card_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          year: map['year'] as int,
          month: map['month'] as int,
          effectiveDay: map['effective_day'] as int? ?? 1,
          syncStatus: 'synced',
          updatedAt: map['updated_at']?.toString(),
          createdAt: map['created_at']?.toString(),
        );
        await minRepo.upsertFromRemote(m);
      }
    }

    final debtRes = await _supabase.from('debts').select().eq('user_id', userId);
    for (final row in debtRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final dueDateTime = tryParseDateOnly(map['due_date']?.toString());
      final d = Debt(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        totalAmount: (map['total_amount'] as num).toDouble(),
        numberOfInstallments: map['number_of_installments'] as int,
        dueDate: dueDateTime,
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
        status: DebtStatusX.fromWire(map['status'] as String?),
      );
      await debtRepo.upsertFromRemote(d);
    }

    final debtIds = (await debtRepo.getAll(userId)).map((d) => d.id).toList();
    for (final debtId in debtIds) {
      final payRes = await _supabase.from('debt_payments').select().eq('debt_id', debtId);
      for (final row in payRes as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final p = DebtPayment(
          id: map['id'] as String,
          debtId: map['debt_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          date: parseDateOnly(map['date'] as String),
          syncStatus: 'synced',
          updatedAt: map['updated_at']?.toString(),
          createdAt: map['created_at']?.toString(),
        );
        await debtPayRepo.upsertFromRemote(p);
      }
    }

    final receivableRes = await _supabase.from('receivables').select().eq('user_id', userId);
    for (final row in receivableRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final r = Receivable(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        debtorName: map['debtor_name'] as String,
        debtorEmail: map['debtor_email'] as String?,
        totalAmount: (map['total_amount'] as num).toDouble(),
        description: map['description'] as String?,
        dueDate: map['due_date'] != null ? tryParseDateOnly(map['due_date'].toString()) : null,
        status: ReceivableStatusX.fromWire(map['status'] as String?),
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
      );
      await receivableRepo.upsertFromRemote(r);
    }

    final receivableIds = (await receivableRepo.getAll(userId)).map((r) => r.id).toList();
    for (final receivableId in receivableIds) {
      final payRes = await _supabase
          .from('receivable_payments')
          .select()
          .eq('receivable_id', receivableId);
      for (final row in payRes as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final p = ReceivablePayment(
          id: map['id'] as String,
          receivableId: map['receivable_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          date: parseDateOnly(map['date'] as String),
          note: map['note'] as String?,
          syncStatus: 'synced',
          updatedAt: map['updated_at']?.toString(),
          createdAt: map['created_at']?.toString(),
        );
        await receivablePayRepo.upsertFromRemote(p);
      }
    }

    final autoRes = await _supabase.from('automatic_payments').select().eq('user_id', userId);
    for (final row in autoRes as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final nextDate = tryParseDateOnly(map['next_run_date']?.toString());
      final a = AutomaticPayment(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        paymentType: map['payment_type'] as String,
        paymentRef: map['payment_ref'] as String,
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        nextRunDate: nextDate,
        // Fallback null-safe: columnas remotas pueden no existir aún en Supabase
        paymentDayOfMonth: map['payment_day_of_month'] as int? ?? nextDate.day,
        frequency: map['frequency'] as String? ?? 'mensual',
        status: map['status'] as String? ?? 'active',
        syncStatus: 'synced',
        updatedAt: map['updated_at']?.toString(),
        createdAt: map['created_at']?.toString(),
      );
      await autoPayRepo.upsertFromRemote(a);
    }

    await _pullMirroredDebts(userId);
  }

  Future<void> _pullMirroredDebts(String userId) async {
    final repo = _ref.read(mirroredDebtRepositoryProvider);
    final res = await _supabase.from('mirrored_debts').select().eq('debtor_user_id', userId);
    final remoteIds = <String>{};
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      remoteIds.add(m['id'] as String);
      await repo.upsertFromRemote(m);
    }
    await repo.pruneAbsent(userId, remoteIds);
    for (final id in remoteIds) {
      final pays = await _supabase
          .from('mirrored_debt_payments')
          .select()
          .eq('mirrored_debt_id', id);
      for (final prow in pays as List) {
        await repo.upsertPaymentFromRemote(Map<String, dynamic>.from(prow as Map));
      }
    }
  }

  Map<String, dynamic> _toRemoteCard(CreditCard c) {
    final m = c.toJson();
    m.remove('sync_status');
    m.remove('updated_at');
    m.remove('created_at');
    return m;
  }

  Map<String, dynamic> _toRemotePaymentMethod(PaymentMethod p) {
    final m = p.toJson();
    m.remove('sync_status');
    m.remove('updated_at');
    m.remove('created_at');
    return m;
  }

  Map<String, dynamic> _toRemoteExpense(Expense e) {
    final m = e.toJson();
    m.remove('sync_status');
    m.remove('updated_at');
    m.remove('created_at');
    return m;
  }

  Map<String, dynamic> _toRemoteCardPayment(CardPayment p) {
    final m = p.toJson();
    m.remove('sync_status');
    m.remove('updated_at');
    m.remove('created_at');
    return m;
  }

  Map<String, dynamic> _toRemoteMinConfig(MinPaymentConfig m) {
    final map = m.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    return map;
  }

  Map<String, dynamic> _toRemoteDebt(Debt d) {
    final map = d.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    if (map['due_date'] is String) {
      map['due_date'] = dateOnlyIso(DateTime.parse(map['due_date'] as String));
    }
    return map;
  }

  Map<String, dynamic> _toRemoteDebtPayment(DebtPayment p) {
    final map = p.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    return map;
  }

  Map<String, dynamic> _toRemoteAutomaticPayment(AutomaticPayment a) {
    final map = a.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    if (map['next_run_date'] is String) {
      map['next_run_date'] = dateOnlyIso(DateTime.parse(map['next_run_date'] as String));
    }
    // payment_day_of_month y frequency ya están en toJson() — se incluyen por defecto
    return map;
  }

  Map<String, dynamic> _toRemoteReceivable(Receivable r) {
    final map = r.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    if (map['due_date'] is String) {
      map['due_date'] = dateOnlyIso(DateTime.parse(map['due_date'] as String));
    }
    return map;
  }

  Map<String, dynamic> _toRemoteReceivablePayment(ReceivablePayment p) {
    final map = p.toJson();
    map.remove('sync_status');
    map.remove('updated_at');
    map.remove('created_at');
    if (map['date'] is String) {
      map['date'] = dateOnlyIso(DateTime.parse(map['date'] as String));
    }
    return map;
  }
}
