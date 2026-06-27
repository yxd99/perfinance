import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/min_payment_config.dart';

void main() {
  group('MinPaymentConfig serialization', () {
    test('fromJson includes effectiveDay', () {
      final json = {
        'id': 'cfg-1',
        'card_id': 'card-1',
        'amount': 500.0,
        'year': 2026,
        'month': 6,
        'effective_day': 15,
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
      };
      final config = MinPaymentConfig.fromJson(json);
      expect(config.effectiveDay, equals(15));
    });

    test('toJson includes effective_day', () {
      final config = MinPaymentConfig(
        id: 'cfg-1',
        cardId: 'card-1',
        amount: 500.0,
        year: 2026,
        month: 6,
        effectiveDay: 10,
      );
      final json = config.toJson();
      expect(json['effective_day'], equals(10));
    });

    test('fromJson defaults effectiveDay to 1 when key absent', () {
      final json = {
        'id': 'cfg-1',
        'card_id': 'card-1',
        'amount': 300.0,
        'year': 2026,
        'month': 5,
        'sync_status': 'synced',
        'updated_at': null,
        'created_at': null,
        // 'effective_day' intentionally absent (backward compat)
      };
      final config = MinPaymentConfig.fromJson(json);
      expect(config.effectiveDay, equals(1),
          reason: 'legacy rows without effective_day must default to 1');
    });

    test('toJson round-trips effectiveDay', () {
      final original = MinPaymentConfig(
        id: 'cfg-rt',
        cardId: 'card-rt',
        amount: 1000.0,
        year: 2026,
        month: 3,
        effectiveDay: 25,
      );
      final roundTripped = MinPaymentConfig.fromJson(original.toJson());
      expect(roundTripped.effectiveDay, equals(25));
      expect(roundTripped.amount, equals(1000.0));
    });

    test('constructor defaults effectiveDay to 1', () {
      final config = MinPaymentConfig(
        id: 'cfg-def',
        cardId: 'card-def',
        amount: 200.0,
        year: 2026,
        month: 7,
      );
      expect(config.effectiveDay, equals(1));
    });
  });
}
