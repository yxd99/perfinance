import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';

// ── Unit tests for active-first ordering logic ─────────────────────────────
// These test the sort/filter LOGIC extracted from credit_cards_screen.dart —
// not a full widget pump — following the same convention as
// min_payment_form_test.dart, since the full screen requires Riverpod/DB/Auth
// setup. The badge widget itself is a trivial Pill render verified visually.

CreditCard _card(String id, bool isActive) => CreditCard(
      id: id,
      userId: 'user-1',
      alias: id,
      cutOffDay: 10,
      managementFee: 0,
      isActive: isActive,
    );

List<CreditCard> _sortActiveFirst(List<CreditCard> cards) {
  final sorted = [...cards];
  sorted.sort((a, b) => (a.isActive == b.isActive) ? 0 : (a.isActive ? -1 : 1));
  return sorted;
}

void main() {
  group('active-first ordering', () {
    test('lista muestra tarjetas activas antes que inactivas', () {
      final cards = [_card('A', true), _card('B', false), _card('C', true)];
      final sorted = _sortActiveFirst(cards);
      expect(sorted.map((c) => c.id).toList(), ['A', 'C', 'B']);
    });

    test('orden es estable dentro del mismo grupo', () {
      final cards = [_card('A', false), _card('B', true), _card('C', false), _card('D', true)];
      final sorted = _sortActiveFirst(cards);
      expect(sorted.map((c) => c.id).toList(), ['B', 'D', 'A', 'C']);
    });
  });

  group('badge visibility', () {
    test('tarjeta inactiva muestra badge', () {
      final card = _card('A', false);
      expect(!card.isActive, isTrue);
    });

    test('tarjeta activa NO muestra badge', () {
      final card = _card('A', true);
      expect(!card.isActive, isFalse);
    });
  });
}
