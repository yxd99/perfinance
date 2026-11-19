import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/expenses/widgets/account_picker.dart';

void main() {
  const all = [
    AccountChoice('c1', 'Visa Oro', isCard: true),
    AccountChoice('c2', 'Mastercard Éxito', isCard: true),
    AccountChoice('m1', 'Débito Bancolombia', isCard: false),
    AccountChoice('m2', 'Efectivo', isCard: false),
  ];

  group('filterAccountChoices', () {
    test('sin búsqueda devuelve todo, en el mismo orden', () {
      expect(filterAccountChoices(all, '  '), all);
    });

    test('ignora mayúsculas y tildes', () {
      expect(filterAccountChoices(all, 'DEBITO').map((a) => a.id), ['m1']);
      expect(filterAccountChoices(all, 'exito').map((a) => a.id), ['c2']);
    });

    test('busca en cualquier parte del nombre', () {
      expect(filterAccountChoices(all, 'oro').map((a) => a.id), ['c1']);
    });

    test('sin coincidencias devuelve vacío', () {
      expect(filterAccountChoices(all, 'nequi'), isEmpty);
    });
  });
}
