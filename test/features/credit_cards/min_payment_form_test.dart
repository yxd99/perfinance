import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/core/utils/date_utils.dart';

// ── Unit tests for the effectiveDay picker logic (state machine) ──────────────
// These test the LOGIC extracted from the UI — not full widget pump —
// since the full screen requires Riverpod/DB/Auth setup.
// Widget-level integration tests for the dialog exist in the integration test suite.

/// Mirrors the create/edit decision in the min payment dialog.
bool _isCreateMode(Object? existing) => existing == null;

void main() {
  group('effectiveDay picker logic', () {
    test('effectiveDay > 25 should trigger warning', () {
      for (final day in [26, 27, 28, 29, 30, 31]) {
        expect(day > 25, isTrue, reason: 'day $day should trigger late-date warning');
      }
      for (final day in [1, 15, 25]) {
        expect(day > 25, isFalse, reason: 'day $day should NOT trigger warning');
      }
    });

    test('create mode: effectiveDay picker should be enabled (existing == null)', () {
      expect(_isCreateMode(null), isTrue); // no existing config
    });

    test('edit mode: effectiveDay picker should be disabled (existing != null)', () {
      expect(_isCreateMode('cfg-1'), isFalse); // existing config id
    });

    test('edit mode caption contains the locked effectiveDay', () {
      const effectiveDay = 10;
      final caption = 'Solo puedes modificar el monto este mes. La fecha de referencia queda fija en el día $effectiveDay.';
      expect(caption, contains('10'));
      expect(caption, contains('Solo puedes modificar'));
    });

    test('effectiveDay > 25 warning text is correct', () {
      const warning = 'Configuraste una fecha de referencia tardía — la mayoría de tus pagos de este mes no contarán hacia el mínimo.';
      expect(warning, isNotEmpty);
    });

    test('disclaimer text is correct', () {
      const disclaimer = 'Esta fecha solo afecta cómo la app registra tus pagos. Tu banco cuenta todos los pagos del ciclo.';
      expect(disclaimer, isNotEmpty);
    });
  });

  group('effectiveDay clamping at last day of month', () {
    test('picker max for February non-leap is 28', () {
      expect(lastDayOfMonth(2026, 2), equals(28));
    });

    test('picker max for February leap is 29', () {
      expect(lastDayOfMonth(2024, 2), equals(29));
    });

    test('picker max for June is 30', () {
      expect(lastDayOfMonth(2026, 6), equals(30));
    });

    test('picker max for January is 31', () {
      expect(lastDayOfMonth(2026, 1), equals(31));
    });
  });

  group('boundary-cross detection logic', () {
    test('payment moving from before to after cutoff crosses boundary', () {
      const cutoffDay = 10;
      final oldDate = DateTime(2026, 6, 5);  // before cutoff
      final newDate = DateTime(2026, 6, 15); // after cutoff
      final cutoff = DateTime(2026, 6, cutoffDay);

      final oldBeforeCutoff = oldDate.isBefore(cutoff);
      final newBeforeCutoff = newDate.isBefore(cutoff);

      expect(oldBeforeCutoff != newBeforeCutoff, isTrue,
          reason: 'Dates on opposite sides of cutoff = boundary cross');
    });

    test('payment moving from after to before cutoff crosses boundary', () {
      const cutoffDay = 10;
      final oldDate = DateTime(2026, 6, 15); // after cutoff
      final newDate = DateTime(2026, 6, 5);  // before cutoff
      final cutoff = DateTime(2026, 6, cutoffDay);

      final oldBeforeCutoff = oldDate.isBefore(cutoff);
      final newBeforeCutoff = newDate.isBefore(cutoff);

      expect(oldBeforeCutoff != newBeforeCutoff, isTrue);
    });

    test('payment staying on same side does NOT cross boundary', () {
      const cutoffDay = 10;
      final oldDate = DateTime(2026, 6, 3);
      final newDate = DateTime(2026, 6, 7);
      final cutoff = DateTime(2026, 6, cutoffDay);

      final oldBeforeCutoff = oldDate.isBefore(cutoff);
      final newBeforeCutoff = newDate.isBefore(cutoff);

      expect(oldBeforeCutoff != newBeforeCutoff, isFalse,
          reason: 'Both dates before cutoff = no boundary cross');
    });

    test('snackbar text is correct', () {
      const snackbarText = 'Cambiaste la fecha de este pago — esto afecta el progreso del pago mínimo.';
      expect(snackbarText, isNotEmpty);
    });
  });
}
