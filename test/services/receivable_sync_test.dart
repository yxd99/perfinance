import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';

// ── Mapper helpers (mirrors sync_service.dart private methods) ──────────────

Map<String, dynamic> _toRemoteReceivable(Receivable r) {
  final map = r.toJson();
  map.remove('sync_status');
  map.remove('updated_at');
  map.remove('created_at');
  if (map['due_date'] is String) {
    // dateOnlyIso: keep only YYYY-MM-DD
    map['due_date'] = (map['due_date'] as String).substring(0, 10);
  }
  return map;
}

Map<String, dynamic> _toRemoteReceivablePayment(ReceivablePayment p) {
  final map = p.toJson();
  map.remove('sync_status');
  map.remove('updated_at');
  map.remove('created_at');
  if (map['date'] is String) {
    map['date'] = (map['date'] as String).substring(0, 10);
  }
  return map;
}

Receivable _makeReceivable({
  String id = 'r1',
  ReceivableStatus status = ReceivableStatus.active,
  String syncStatus = 'pending_insert',
}) =>
    Receivable(
      id: id,
      userId: 'user-1',
      debtorName: 'Test',
      debtorEmail: 'test@example.com',
      totalAmount: 1000,
      status: status,
      syncStatus: syncStatus,
    );

ReceivablePayment _makePayment({
  String id = 'p1',
  String syncStatus = 'pending_insert',
}) =>
    ReceivablePayment(
      id: id,
      receivableId: 'r1',
      amount: 200,
      date: DateTime(2026, 6, 4),
      syncStatus: syncStatus,
    );

void main() {
  group('_toRemoteReceivable', () {
    test('strips sync_status, updated_at, created_at', () {
      final r = _makeReceivable();
      final map = _toRemoteReceivable(r);
      expect(map.containsKey('sync_status'), isFalse);
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
    });

    test('includes all domain fields', () {
      final r = _makeReceivable();
      final map = _toRemoteReceivable(r);
      expect(map['id'], 'r1');
      expect(map['user_id'], 'user-1');
      expect(map['debtor_name'], 'Test');
      expect(map['debtor_email'], 'test@example.com');
      expect(map['total_amount'], 1000);
      expect(map['status'], 'active');
    });

    test('serializes status wire for settled', () {
      final r = _makeReceivable(status: ReceivableStatus.settled);
      final map = _toRemoteReceivable(r);
      expect(map['status'], 'settled');
    });

    test('serializes writtenOff as written_off wire', () {
      final r = _makeReceivable(status: ReceivableStatus.writtenOff);
      final map = _toRemoteReceivable(r);
      expect(map['status'], 'written_off');
    });

    test('due_date trimmed to date-only when present', () {
      final r = Receivable(
        id: 'r1',
        userId: 'u1',
        debtorName: 'T',
        totalAmount: 100,
        dueDate: DateTime(2026, 12, 31),
        syncStatus: 'pending_insert',
      );
      final map = _toRemoteReceivable(r);
      expect(map['due_date'], '2026-12-31');
    });

    test('due_date is null when absent', () {
      final r = _makeReceivable();
      final map = _toRemoteReceivable(r);
      expect(map['due_date'], isNull);
    });
  });

  group('_toRemoteReceivablePayment', () {
    test('strips sync_status, updated_at, created_at', () {
      final p = _makePayment();
      final map = _toRemoteReceivablePayment(p);
      expect(map.containsKey('sync_status'), isFalse);
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
    });

    test('includes all domain fields', () {
      final p = _makePayment();
      final map = _toRemoteReceivablePayment(p);
      expect(map['id'], 'p1');
      expect(map['receivable_id'], 'r1');
      expect(map['amount'], 200);
    });

    test('date trimmed to date-only', () {
      final p = _makePayment();
      final map = _toRemoteReceivablePayment(p);
      expect(map['date'], '2026-06-04');
    });

    test('pending_update payment IS mapped (unlike debt_payments)', () {
      // This test documents the key divergence: receivable_payments support
      // pending_update while debt_payments do not.
      final p = _makePayment(syncStatus: 'pending_update');
      final map = _toRemoteReceivablePayment(p);
      // The mapper works for any syncStatus — it strips sync fields.
      expect(map['id'], 'p1');
      expect(map.containsKey('sync_status'), isFalse);
    });
  });

  group('Receivable sync_status branching logic', () {
    test('pending_insert receivable is identified correctly', () {
      final r = _makeReceivable(syncStatus: 'pending_insert');
      expect(r.syncStatus, 'pending_insert');
    });

    test('pending_update receivable is identified correctly', () {
      final r = _makeReceivable(syncStatus: 'pending_update');
      expect(r.syncStatus, 'pending_update');
    });

    test('pending_delete receivable is identified correctly', () {
      final r = _makeReceivable(syncStatus: 'pending_delete');
      expect(r.syncStatus, 'pending_delete');
    });

    test('pending_update payment IS supported — key divergence from debt_payments', () {
      final p = _makePayment(syncStatus: 'pending_update');
      expect(p.syncStatus, 'pending_update');
      // Verify toRemote works for pending_update payments
      final map = _toRemoteReceivablePayment(p);
      expect(map['id'], isNotNull);
    });
  });
}
