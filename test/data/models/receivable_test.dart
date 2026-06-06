import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';

void main() {
  group('ReceivableStatus wire round-trips', () {
    test('writtenOff serializes to wire written_off', () {
      expect(ReceivableStatus.writtenOff.wire, 'written_off');
    });

    test('active serializes to wire active', () {
      expect(ReceivableStatus.active.wire, 'active');
    });

    test('settled serializes to wire settled', () {
      expect(ReceivableStatus.settled.wire, 'settled');
    });

    test('hidden serializes to wire hidden', () {
      expect(ReceivableStatus.hidden.wire, 'hidden');
    });

    test('fromWire written_off returns writtenOff', () {
      expect(ReceivableStatusX.fromWire('written_off'), ReceivableStatus.writtenOff);
    });

    test('fromWire settled returns settled', () {
      expect(ReceivableStatusX.fromWire('settled'), ReceivableStatus.settled);
    });

    test('fromWire hidden returns hidden', () {
      expect(ReceivableStatusX.fromWire('hidden'), ReceivableStatus.hidden);
    });

    test('fromWire null defaults to active', () {
      expect(ReceivableStatusX.fromWire(null), ReceivableStatus.active);
    });

    test('fromWire unknown string defaults to active', () {
      expect(ReceivableStatusX.fromWire('foo'), ReceivableStatus.active);
    });

    test('writtenOff enum.name is writtenOff not written_off (verifying wire is needed)', () {
      // This test documents WHY we need a custom wire: .name would give 'writtenOff'
      expect(ReceivableStatus.writtenOff.name, 'writtenOff');
      expect(ReceivableStatus.writtenOff.wire, isNot('writtenOff'));
    });
  });

  group('Receivable toJson/fromJson round-trip', () {
    test('round-trips a fully populated receivable', () {
      final receivable = Receivable(
        id: 'recv-1',
        userId: 'user-1',
        debtorName: 'John Doe',
        debtorEmail: 'john@example.com',
        totalAmount: 1000.0,
        description: 'Loan for car repair',
        dueDate: DateTime(2026, 12, 31),
        status: ReceivableStatus.active,
        syncStatus: 'synced',
        updatedAt: '2026-01-01T00:00:00.000',
        createdAt: '2026-01-01T00:00:00.000',
      );

      final json = receivable.toJson();
      final restored = Receivable.fromJson(json);

      expect(restored.id, receivable.id);
      expect(restored.userId, receivable.userId);
      expect(restored.debtorName, receivable.debtorName);
      expect(restored.debtorEmail, receivable.debtorEmail);
      expect(restored.totalAmount, receivable.totalAmount);
      expect(restored.description, receivable.description);
      expect(restored.dueDate, receivable.dueDate);
      expect(restored.status, receivable.status);
      expect(restored.syncStatus, receivable.syncStatus);
      expect(restored.updatedAt, receivable.updatedAt);
      expect(restored.createdAt, receivable.createdAt);
    });

    test('round-trips with null debtorEmail and null dueDate', () {
      final receivable = Receivable(
        id: 'recv-2',
        userId: 'user-1',
        debtorName: 'Jane Doe',
        debtorEmail: null,
        totalAmount: 500.0,
        dueDate: null,
        status: ReceivableStatus.active,
      );

      final restored = Receivable.fromJson(receivable.toJson());

      expect(restored.debtorEmail, isNull);
      expect(restored.dueDate, isNull);
    });

    test('toJson uses wire value for status writtenOff', () {
      final receivable = Receivable(
        id: 'recv-3',
        userId: 'user-1',
        debtorName: 'Bob',
        totalAmount: 200.0,
        status: ReceivableStatus.writtenOff,
      );
      expect(receivable.toJson()['status'], 'written_off');
    });

    test('toJson includes debtor_name, debtor_email, total_amount keys', () {
      final receivable = Receivable(
        id: 'recv-4',
        userId: 'user-1',
        debtorName: 'Alice',
        debtorEmail: 'alice@example.com',
        totalAmount: 750.0,
      );
      final json = receivable.toJson();
      expect(json, containsPair('debtor_name', 'Alice'));
      expect(json, containsPair('debtor_email', 'alice@example.com'));
      expect(json, containsPair('total_amount', 750.0));
    });

    test('fromJson with no status key defaults to active', () {
      final json = {
        'id': 'recv-5',
        'user_id': 'user-1',
        'debtor_name': 'Test',
        'total_amount': 100.0,
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
      };
      expect(Receivable.fromJson(json).status, ReceivableStatus.active);
    });

    test('default syncStatus is synced', () {
      final r = Receivable(
        id: 'r',
        userId: 'u',
        debtorName: 'D',
        totalAmount: 1.0,
      );
      expect(r.syncStatus, 'synced');
    });
  });
}
