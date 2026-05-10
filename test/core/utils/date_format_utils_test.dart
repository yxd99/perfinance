import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';

void main() {
  group('formatDisplayDate', () {
    test('enero — mes 1', () {
      expect(formatDisplayDate(DateTime(2026, 1, 1)), '1 ene 2026');
    });

    test('febrero — mes 2', () {
      expect(formatDisplayDate(DateTime(2026, 2, 14)), '14 feb 2026');
    });

    test('marzo — mes 3', () {
      expect(formatDisplayDate(DateTime(2026, 3, 31)), '31 mar 2026');
    });

    test('abril — mes 4', () {
      expect(formatDisplayDate(DateTime(2026, 4, 5)), '5 abr 2026');
    });

    test('mayo — mes 5', () {
      expect(formatDisplayDate(DateTime(2026, 5, 15)), '15 may 2026');
    });

    test('junio — mes 6', () {
      expect(formatDisplayDate(DateTime(2026, 6, 20)), '20 jun 2026');
    });

    test('julio — mes 7', () {
      expect(formatDisplayDate(DateTime(2026, 7, 4)), '4 jul 2026');
    });

    test('agosto — mes 8', () {
      expect(formatDisplayDate(DateTime(2026, 8, 8)), '8 ago 2026');
    });

    test('septiembre — mes 9', () {
      expect(formatDisplayDate(DateTime(2026, 9, 30)), '30 sep 2026');
    });

    test('octubre — mes 10', () {
      expect(formatDisplayDate(DateTime(2026, 10, 10)), '10 oct 2026');
    });

    test('noviembre — mes 11', () {
      expect(formatDisplayDate(DateTime(2026, 11, 22)), '22 nov 2026');
    });

    test('diciembre — mes 12', () {
      expect(formatDisplayDate(DateTime(2026, 12, 25)), '25 dic 2026');
    });

    test('día sin padding — día 5 no es 05', () {
      expect(formatDisplayDate(DateTime(2026, 3, 5)), '5 mar 2026');
    });

    test('año bisiesto — feb 29 2028', () {
      expect(formatDisplayDate(DateTime(2028, 2, 29)), '29 feb 2028');
    });

    test('año distinto — 2020', () {
      expect(formatDisplayDate(DateTime(2020, 6, 1)), '1 jun 2020');
    });

    test('año distinto — 2030', () {
      expect(formatDisplayDate(DateTime(2030, 11, 11)), '11 nov 2030');
    });

    test('DateTime.utc — sin conversión de zona', () {
      expect(formatDisplayDate(DateTime.utc(2026, 3, 10)), '10 mar 2026');
    });
  });
}
