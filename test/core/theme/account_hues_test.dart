import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/account_hues.dart';
import 'package:perfinance/core/theme/app_colors.dart';

void main() {
  group('assignHueSlots', () {
    test('ordena por fecha de creación y asigna posiciones consecutivas', () {
      final slots = assignHueSlots([
        (id: 'c', createdAt: '2026-03-01T00:00:00Z'),
        (id: 'a', createdAt: '2026-01-01T00:00:00Z'),
        (id: 'b', createdAt: '2026-02-01T00:00:00Z'),
      ]);
      expect(slots, {'a': 0, 'b': 1, 'c': 2});
    });

    test('sin fecha van al final, desempatando por id', () {
      final slots = assignHueSlots([
        (id: 'z', createdAt: null),
        (id: 'y', createdAt: null),
        (id: 'x', createdAt: '2026-01-01T00:00:00Z'),
      ]);
      expect(slots, {'x': 0, 'y': 1, 'z': 2});
    });

    test('ids repetidos conservan su primera posición', () {
      final slots = assignHueSlots([
        (id: 'a', createdAt: '2026-01-01T00:00:00Z'),
        (id: 'a', createdAt: '2026-01-01T00:00:00Z'),
        (id: 'b', createdAt: '2026-02-01T00:00:00Z'),
      ]);
      expect(slots, {'a': 0, 'b': 1});
    });
  });

  group('AppColors.accountColorFor', () {
    const c = AppColors.light;

    test('cinco cuentas reciben cinco tonos distintos', () {
      final ids = ['nu', 'nequi', 'visa', 'master', 'cash'];
      final slots = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      final colors = ids.map((id) => c.accountColorFor(id, slots)).toSet();
      expect(colors.length, 5);
    });

    test('una cuenta sin posición usa el tono estable por id', () {
      expect(c.accountColorFor('desconocida', const {}), c.accountColor('desconocida'));
    });
  });
}
