import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/date_utils.dart';

void main() {
  group('lastDayOfMonth', () {
    test('returns 28 for February in non-leap year', () {
      expect(lastDayOfMonth(2026, 2), equals(28));
    });

    test('returns 29 for February in leap year', () {
      expect(lastDayOfMonth(2024, 2), equals(29));
    });

    test('returns 31 for January', () {
      expect(lastDayOfMonth(2026, 1), equals(31));
    });

    test('returns 30 for April', () {
      expect(lastDayOfMonth(2026, 4), equals(30));
    });

    test('returns 31 for December', () {
      expect(lastDayOfMonth(2026, 12), equals(31));
    });
  });

  group('clampEffectiveDay', () {
    test('clamps 31 to 28 in February non-leap year', () {
      expect(clampEffectiveDay(31, 2026, 2), equals(28));
    });

    test('clamps 31 to 29 in February leap year', () {
      expect(clampEffectiveDay(31, 2024, 2), equals(29));
    });

    test('leaves 15 unchanged in any month', () {
      expect(clampEffectiveDay(15, 2026, 1), equals(15));
      expect(clampEffectiveDay(15, 2026, 6), equals(15));
      expect(clampEffectiveDay(15, 2026, 12), equals(15));
    });

    test('clamps 0 to 1', () {
      expect(clampEffectiveDay(0, 2026, 6), equals(1));
    });

    test('clamps negative to 1', () {
      expect(clampEffectiveDay(-5, 2026, 3), equals(1));
    });

    test('leaves 31 unchanged in January', () {
      expect(clampEffectiveDay(31, 2026, 1), equals(31));
    });

    test('clamps 31 to 30 in April', () {
      expect(clampEffectiveDay(31, 2026, 4), equals(30));
    });
  });
}
