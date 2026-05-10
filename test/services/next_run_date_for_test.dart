import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/services/process_automatic_payments_service.dart';

void main() {
  group('nextRunDateFor', () {
    test('mensual día 15 normal', () {
      final result = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 15,
        from: DateTime(2024, 1, 15),
      );
      expect(result, DateTime(2024, 2, 15));
    });

    test('mensual día 31 enero→febrero año bisiesto (→29)', () {
      final result = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 31,
        from: DateTime(2024, 1, 31),
      );
      expect(result, DateTime(2024, 2, 29));
    });

    test('mensual día 31 enero→febrero año no bisiesto (→28)', () {
      final result = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 31,
        from: DateTime(2023, 1, 31),
      );
      expect(result, DateTime(2023, 2, 28));
    });

    test('mensual día 29 en febrero bisiesto', () {
      final result = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 29,
        from: DateTime(2024, 1, 29),
      );
      expect(result, DateTime(2024, 2, 29));
    });

    test('mensual día 29 en febrero no bisiesto (→28)', () {
      final result = nextRunDateFor(
        frequency: 'mensual',
        dayOfMonth: 29,
        from: DateTime(2023, 1, 29),
      );
      expect(result, DateTime(2023, 2, 28));
    });

    test('trimestral día 15', () {
      final result = nextRunDateFor(
        frequency: 'trimestral',
        dayOfMonth: 15,
        from: DateTime(2024, 1, 15),
      );
      expect(result, DateTime(2024, 4, 15));
    });

    test('semestral día 15', () {
      final result = nextRunDateFor(
        frequency: 'semestral',
        dayOfMonth: 15,
        from: DateTime(2024, 1, 15),
      );
      expect(result, DateTime(2024, 7, 15));
    });

    test('anual día 15', () {
      final result = nextRunDateFor(
        frequency: 'anual',
        dayOfMonth: 15,
        from: DateTime(2024, 1, 15),
      );
      expect(result, DateTime(2025, 1, 15));
    });

    test('anual día 29 febrero bisiesto→no bisiesto (→28)', () {
      final result = nextRunDateFor(
        frequency: 'anual',
        dayOfMonth: 29,
        from: DateTime(2024, 2, 29),
      );
      expect(result, DateTime(2025, 2, 28));
    });
  });
}
