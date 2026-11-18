import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/theme/account_hues.dart';

void main() {
  test('el color elegido gana; el resto conserva su color automático', () {
    final auto = assignHueSlots([
      (id: 'a', createdAt: '2026-01-01'),
      (id: 'b', createdAt: '2026-02-01'),
      (id: 'c', createdAt: '2026-03-01'),
    ]);
    expect(auto, {'a': 0, 'b': 1, 'c': 2});
    expect(applyChosenHueSlots(auto, {'b': 4, 'c': null}), {'a': 0, 'b': 4, 'c': 2});
  });

  test('un color elegido fuera de la paleta se ignora', () {
    expect(applyChosenHueSlots({'a': 0}, {'a': 9}), {'a': 0});
    expect(applyChosenHueSlots({'a': 0}, {'a': -1}), {'a': 0});
  });
}
