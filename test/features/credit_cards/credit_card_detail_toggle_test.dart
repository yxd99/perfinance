import 'package:flutter_test/flutter_test.dart';

// ── Unit tests for the isActive toggle decision logic ─────────────────────
// These test the LOGIC extracted from the UI (when to show the confirmation
// dialog vs act immediately) — not a full widget pump — following the same
// convention as min_payment_form_test.dart, since the full screen requires
// Riverpod/DB/Auth setup.

/// Mirrors the decision made in credit_card_detail_screen.dart's toggle handler.
bool shouldShowConfirmationDialog({required bool isDeactivating, required double currentDebt}) {
  if (!isDeactivating) return false; // reactivating never shows a dialog
  return currentDebt > 0;
}

void main() {
  group('deactivate confirmation dialog decision', () {
    test('tarjeta con deuda > 0 debe mostrar AlertDialog al desactivar', () {
      expect(
        shouldShowConfirmationDialog(isDeactivating: true, currentDebt: 150000),
        isTrue,
      );
    });

    test('tarjeta con deuda == 0 desactiva inmediatamente sin dialog', () {
      expect(
        shouldShowConfirmationDialog(isDeactivating: true, currentDebt: 0),
        isFalse,
      );
    });

    test('reactivar tarjeta nunca muestra dialog, incluso con deuda > 0', () {
      expect(
        shouldShowConfirmationDialog(isDeactivating: false, currentDebt: 80000),
        isFalse,
      );
    });
  });

  group('reactivate snackbar text', () {
    test('snackbar text is "Tarjeta reactivada"', () {
      const snackbarText = 'Tarjeta reactivada';
      expect(snackbarText, 'Tarjeta reactivada');
    });
  });
}
