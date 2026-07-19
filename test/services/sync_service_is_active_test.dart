import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';

CreditCard _makeCard({bool isActive = true}) {
  return CreditCard(
    id: 'card-1',
    userId: 'user-1',
    alias: 'Visa',
    cutOffDay: 10,
    managementFee: 0,
    isActive: isActive,
    syncStatus: 'pending_update',
  );
}

Map<String, dynamic> _toRemoteCard(CreditCard c) {
  final m = c.toJson();
  m.remove('sync_status');
  m.remove('updated_at');
  m.remove('created_at');
  return m;
}

CreditCard _fromRemoteCardRow(Map<String, dynamic> map) {
  return CreditCard(
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
}

AutomaticPayment _makePayment({String status = 'active'}) {
  return AutomaticPayment(
    id: 'auto-1',
    userId: 'user-1',
    paymentType: 'credit_card',
    paymentRef: 'card-1',
    amount: 1000,
    description: 'Pago tarjeta',
    nextRunDate: DateTime(2026, 7, 10),
    status: status,
    syncStatus: 'pending_update',
  );
}

Map<String, dynamic> _toRemoteAutomaticPayment(AutomaticPayment a) {
  final map = a.toJson();
  map.remove('sync_status');
  map.remove('updated_at');
  map.remove('created_at');
  return map;
}

AutomaticPayment _fromRemoteAutoRow(Map<String, dynamic> map) {
  final nextDate = DateTime.parse(map['next_run_date'] as String);
  return AutomaticPayment(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    paymentType: map['payment_type'] as String,
    paymentRef: map['payment_ref'] as String,
    amount: (map['amount'] as num).toDouble(),
    description: map['description'] as String,
    nextRunDate: nextDate,
    paymentDayOfMonth: map['payment_day_of_month'] as int? ?? nextDate.day,
    frequency: map['frequency'] as String? ?? 'mensual',
    status: map['status'] as String? ?? 'active',
    syncStatus: 'synced',
    updatedAt: map['updated_at']?.toString(),
    createdAt: map['created_at']?.toString(),
  );
}

void main() {
  group('sync_service credit_cards is_active mapping', () {
    test('push envía is_active en _toRemoteCard', () {
      final map = _toRemoteCard(_makeCard(isActive: false));
      expect(map.containsKey('is_active'), isTrue);
      expect(map['is_active'], false);
    });

    test('pull mapea is_active remoto a CreditCard local (no default true)', () {
      final row = {
        'id': 'card-1',
        'user_id': 'user-1',
        'alias': 'Visa',
        'cut_off_day': 10,
        'management_fee': 0.0,
        'is_active': false,
        'updated_at': null,
        'created_at': null,
      };
      final c = _fromRemoteCardRow(row);
      expect(c.isActive, false);
    });

    test('pull defaults isActive=true cuando remoto no manda is_active (compat)', () {
      final row = {
        'id': 'card-1',
        'user_id': 'user-1',
        'alias': 'Visa',
        'cut_off_day': 10,
        'management_fee': 0.0,
        'updated_at': null,
        'created_at': null,
      };
      final c = _fromRemoteCardRow(row);
      expect(c.isActive, true);
    });
  });

  group('sync_service automatic_payments status mapping', () {
    test('push envía status en payload', () {
      final map = _toRemoteAutomaticPayment(_makePayment(status: 'paused'));
      expect(map.containsKey('status'), isTrue);
      expect(map['status'], 'paused');
    });

    test('pull mapea status remoto a AutomaticPayment local', () {
      final row = {
        'id': 'auto-1',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 1000.0,
        'description': 'Pago tarjeta',
        'next_run_date': DateTime(2026, 7, 10).toIso8601String(),
        'status': 'paused',
        'updated_at': null,
        'created_at': null,
      };
      final p = _fromRemoteAutoRow(row);
      expect(p.status, 'paused');
    });

    test('pull defaults status=active cuando remoto no manda status (compat)', () {
      final row = {
        'id': 'auto-1',
        'user_id': 'user-1',
        'payment_type': 'credit_card',
        'payment_ref': 'card-1',
        'amount': 1000.0,
        'description': 'Pago tarjeta',
        'next_run_date': DateTime(2026, 7, 10).toIso8601String(),
        'updated_at': null,
        'created_at': null,
      };
      final p = _fromRemoteAutoRow(row);
      expect(p.status, 'active');
    });
  });
}
