import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';

void main() {
  group('CreditCard.isActive', () {
    test('toJson incluye is_active', () {
      final card = CreditCard(
        id: 'card-1',
        userId: 'user-1',
        alias: 'Visa',
        cutOffDay: 10,
        managementFee: 0,
        isActive: false,
      );
      expect(card.toJson()['is_active'], false);
    });

    test('fromJson respeta is_active=false', () {
      final json = {
        'id': 'card-1',
        'user_id': 'user-1',
        'alias': 'Visa',
        'cut_off_day': 10,
        'management_fee': 0.0,
        'is_active': false,
      };
      final card = CreditCard.fromJson(json);
      expect(card.isActive, false);
    });

    test('fromJson sin is_active default true (backward-compat pull viejo)', () {
      final json = {
        'id': 'card-1',
        'user_id': 'user-1',
        'alias': 'Visa',
        'cut_off_day': 10,
        'management_fee': 0.0,
      };
      final card = CreditCard.fromJson(json);
      expect(card.isActive, true);
    });

    test('copyWith cambia solo isActive', () {
      final card = CreditCard(
        id: 'card-1',
        userId: 'user-1',
        alias: 'Visa',
        cutOffDay: 10,
        managementFee: 0,
      );
      final updated = card.copyWith(isActive: false);
      expect(updated.isActive, false);
      expect(updated.alias, 'Visa');
      expect(updated.cutOffDay, 10);
    });

    test('default isActive es true', () {
      final card = CreditCard(
        id: 'card-1',
        userId: 'user-1',
        alias: 'Visa',
        cutOffDay: 10,
        managementFee: 0,
      );
      expect(card.isActive, true);
    });
  });
}
