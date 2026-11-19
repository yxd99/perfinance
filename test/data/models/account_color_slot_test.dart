import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/payment_method.dart';

void main() {
  test('la tarjeta envía y lee color_slot; sin color es null', () {
    final card = CreditCard(id: 'c', userId: 'u', alias: 'Visa', cutOffDay: 15, managementFee: 0, colorSlot: 2);
    expect(card.toJson()['color_slot'], 2);
    expect(CreditCard.fromJson(card.toJson()).colorSlot, 2);
    final plain = CreditCard(id: 'c', userId: 'u', alias: 'Visa', cutOffDay: 15, managementFee: 0);
    expect(plain.toJson()['color_slot'], isNull);
    expect(plain.copyWith(colorSlot: 4).colorSlot, 4);
  });

  test('la cuenta de ahorro envía y lee color_slot; sin color es null', () {
    final pm = PaymentMethod(id: 'p', userId: 'u', name: 'Nequi', colorSlot: 1);
    expect(pm.toJson()['color_slot'], 1);
    expect(PaymentMethod.fromJson(pm.toJson()).colorSlot, 1);
    expect(PaymentMethod(id: 'p', userId: 'u', name: 'Nequi').toJson()['color_slot'], isNull);
    expect(pm.copyWith(name: 'Otra').colorSlot, 1);
  });
}
