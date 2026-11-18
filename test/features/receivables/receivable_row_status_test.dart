import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';
import 'package:perfinance/features/receivables/receivable_row_status.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';

ReceivableView _view(ReceivableStatus status, {double paid = 0, double total = 500000}) => ReceivableView(
  receivable: Receivable(id: 'r1', userId: 'u1', debtorName: 'Juan', totalAmount: total, status: status),
  payments: [if (paid > 0) ReceivablePayment(id: 'p1', receivableId: 'r1', amount: paid, date: DateTime(2026, 1, 1))],
);

void main() {
  group('receivableRowStatus', () {
    test('activa con saldo: detalle cobrado y "Falta" en warning', () {
      final s = receivableRowStatus(_view(ReceivableStatus.active, paid: 200000));
      expect(s.detail, 'Cobrado \$200.000 de \$500.000');
      expect(s.trailing, 'Falta \$300.000');
      expect(s.tone, ReceivableRowTone.warning);
      expect(s.stamp, isNull);
    });

    test('activa sin saldo: "Cobrado al 100%" en positive', () {
      final s = receivableRowStatus(_view(ReceivableStatus.active, paid: 500000));
      expect(s.trailing, 'Cobrado al 100%');
      expect(s.tone, ReceivableRowTone.positive);
      expect(s.stamp, isNull);
    });

    test('saldada: sello "Saldada" sin texto a la derecha', () {
      final s = receivableRowStatus(_view(ReceivableStatus.settled, paid: 500000));
      expect(s.stamp, 'Saldada');
      expect(s.trailing, isNull);
      expect(s.detail, 'Cobrado \$500.000');
    });

    test('incobrable: línea de estado apagada, sin sello', () {
      final s = receivableRowStatus(_view(ReceivableStatus.writtenOff, paid: 100000));
      expect(s.detail, 'Incobrable · cobrado \$100.000 de \$500.000');
      expect(s.tone, ReceivableRowTone.muted);
      expect(s.stamp, isNull);
      expect(s.trailing, isNull);
    });

    test('cancelada: línea de estado apagada', () {
      final s = receivableRowStatus(_view(ReceivableStatus.hidden));
      expect(s.detail, 'Cancelada · cobrado \$0 de \$500.000');
      expect(s.tone, ReceivableRowTone.muted);
    });
  });
}
