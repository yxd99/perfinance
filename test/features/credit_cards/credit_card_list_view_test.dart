import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/features/credit_cards/credit_card_list_view.dart';

CreditCard _card(String id, {bool isActive = true, int cutOff = 10, double fee = 0}) => CreditCard(
      id: id,
      userId: 'user-1',
      alias: id,
      cutOffDay: cutOff,
      managementFee: fee,
      isActive: isActive,
    );

void main() {
  group('sortCardsActiveFirst', () {
    test('pone las activas antes que las desactivadas', () {
      final sorted = sortCardsActiveFirst([_card('A'), _card('B', isActive: false), _card('C')]);
      expect(sorted.map((c) => c.id).toList(), ['A', 'C', 'B']);
    });

    test('mantiene el orden dentro de cada grupo y no toca la lista original', () {
      final original = [
        _card('A', isActive: false),
        _card('B'),
        _card('C', isActive: false),
        _card('D'),
      ];
      final sorted = sortCardsActiveFirst(original);
      expect(sorted.map((c) => c.id).toList(), ['B', 'D', 'A', 'C']);
      expect(original.map((c) => c.id).toList(), ['A', 'B', 'C', 'D']);
    });
  });

  group('cardStatusLine', () {
    test('tarjeta activa muestra corte y cuota', () {
      final line = cardStatusLine(_card('A', cutOff: 15, fee: 12000), hideValues: false);
      expect(line, r'Corte el día 15 · Cuota $12.000');
    });

    test('tarjeta desactivada empieza con "Desactivada"', () {
      final line = cardStatusLine(_card('A', isActive: false, cutOff: 5, fee: 0), hideValues: false);
      expect(line, r'Desactivada · Corte el día 5 · Cuota $0');
    });

    test('con valores ocultos no muestra la cuota', () {
      final line = cardStatusLine(_card('A', cutOff: 15, fee: 12000), hideValues: true);
      expect(line, isNot(contains('12.000')));
      expect(line, startsWith('Corte el día 15'));
    });
  });
}
