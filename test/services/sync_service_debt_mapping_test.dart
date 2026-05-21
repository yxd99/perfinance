import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/debt.dart';

Debt _makeDebt({DebtStatus status = DebtStatus.active}) {
  return Debt(
    id: 'debt-1',
    userId: 'user-1',
    name: 'Test',
    totalAmount: 1000,
    numberOfInstallments: 12,
    dueDate: DateTime(2026, 12, 31),
    syncStatus: 'synced',
    status: status,
  );
}

Map<String, dynamic> _toRemoteDebt(Debt d) {
  final map = d.toJson();
  map.remove('sync_status');
  map.remove('updated_at');
  map.remove('created_at');
  if (map['due_date'] is String) {
    map['due_date'] = (map['due_date'] as String).substring(0, 10);
  }
  return map;
}

Debt _fromRemoteRow(Map<String, dynamic> row) {
  return Debt(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    name: row['name'] as String,
    totalAmount: (row['total_amount'] as num).toDouble(),
    numberOfInstallments: row['number_of_installments'] as int,
    dueDate: DateTime.parse(row['due_date'] as String),
    syncStatus: 'synced',
    updatedAt: row['updated_at']?.toString(),
    createdAt: row['created_at']?.toString(),
    status: DebtStatusX.fromWire(row['status'] as String?),
  );
}

void main() {
  group('_toRemoteDebt includes status', () {
    test('includes status=active', () {
      final map = _toRemoteDebt(_makeDebt(status: DebtStatus.active));
      expect(map.containsKey('status'), isTrue);
      expect(map['status'], 'active');
    });

    test('includes status=paid', () {
      final map = _toRemoteDebt(_makeDebt(status: DebtStatus.paid));
      expect(map['status'], 'paid');
    });

    test('includes status=hidden', () {
      final map = _toRemoteDebt(_makeDebt(status: DebtStatus.hidden));
      expect(map['status'], 'hidden');
    });
  });

  group('pull from remote constructs Debt with status', () {
    test('populates status=paid from remote row', () {
      final row = {
        'id': 'debt-1',
        'user_id': 'user-1',
        'name': 'Test',
        'total_amount': 1000.0,
        'number_of_installments': 12,
        'due_date': '2026-12-31',
        'status': 'paid',
        'updated_at': null,
        'created_at': null,
      };
      final d = _fromRemoteRow(row);
      expect(d.status, DebtStatus.paid);
    });

    test('populates status=hidden from remote row', () {
      final row = {
        'id': 'debt-1',
        'user_id': 'user-1',
        'name': 'Test',
        'total_amount': 1000.0,
        'number_of_installments': 12,
        'due_date': '2026-12-31',
        'status': 'hidden',
        'updated_at': null,
        'created_at': null,
      };
      final d = _fromRemoteRow(row);
      expect(d.status, DebtStatus.hidden);
    });

    test('defaults to active when remote row omits status', () {
      final row = {
        'id': 'debt-1',
        'user_id': 'user-1',
        'name': 'Test',
        'total_amount': 1000.0,
        'number_of_installments': 12,
        'due_date': '2026-12-31',
        'updated_at': null,
        'created_at': null,
      };
      final d = _fromRemoteRow(row);
      expect(d.status, DebtStatus.active);
    });
  });
}
