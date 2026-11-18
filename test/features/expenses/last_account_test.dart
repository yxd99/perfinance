import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/expenses/last_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resolveLastAccount', () {
    const card = LastAccount(paymentType: 'credit_card', paymentRef: 'card-1');
    const method = LastAccount(paymentType: 'payment_method', paymentRef: 'pm-1');

    test('sin cuenta guardada no preselecciona nada', () {
      expect(resolveLastAccount(null, activeCardIds: {'card-1'}, methodIds: {'pm-1'}), isNull);
    });

    test('devuelve la tarjeta guardada si sigue activa', () {
      expect(resolveLastAccount(card, activeCardIds: {'card-1'}, methodIds: {}), card);
    });

    test('devuelve el medio de pago guardado si sigue existiendo', () {
      expect(resolveLastAccount(method, activeCardIds: {}, methodIds: {'pm-1'}), method);
    });

    test('tarjeta desactivada o borrada: no preselecciona', () {
      expect(resolveLastAccount(card, activeCardIds: {'card-2'}, methodIds: {'pm-1'}), isNull);
    });

    test('medio de pago borrado: no preselecciona', () {
      expect(resolveLastAccount(method, activeCardIds: {'card-1'}, methodIds: {}), isNull);
    });

    test('el id debe existir en el tipo guardado, no en el otro', () {
      const crossed = LastAccount(paymentType: 'credit_card', paymentRef: 'pm-1');
      expect(resolveLastAccount(crossed, activeCardIds: {}, methodIds: {'pm-1'}), isNull);
    });
  });

  group('LastAccountStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sin nada guardado devuelve null', () async {
      expect(await LastAccountStore.load(), isNull);
    });

    test('guarda y recupera la última cuenta', () async {
      const method = LastAccount(paymentType: 'payment_method', paymentRef: 'pm-9');
      await LastAccountStore.save(method);
      expect(await LastAccountStore.load(), method);
    });
  });
}
