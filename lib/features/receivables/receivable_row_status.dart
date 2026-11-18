import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';

/// Tono del texto de estado de un cobro. Es estado, nunca identidad.
enum ReceivableRowTone { warning, positive, muted }

/// Lo que muestra una fila de «Me deben» según el estado del cobro.
///
/// [detail] va debajo del nombre; [trailing] a la derecha (o nada); [stamp]
/// es el texto del sello de tinta cuando el cobro ya se cerró.
typedef ReceivableRowStatus = ({String detail, String? trailing, ReceivableRowTone tone, String? stamp});

ReceivableRowStatus receivableRowStatus(ReceivableView view) {
  final r = view.receivable;
  final paid = '\$${formatCurrency(view.totalPaid)}';
  final total = '\$${formatCurrency(r.totalAmount)}';
  switch (r.status) {
    case ReceivableStatus.settled:
      return (detail: 'Cobrado $total', trailing: null, tone: ReceivableRowTone.muted, stamp: 'Saldada');
    case ReceivableStatus.writtenOff:
      return (
        detail: 'Incobrable · cobrado $paid de $total',
        trailing: null,
        tone: ReceivableRowTone.muted,
        stamp: null,
      );
    case ReceivableStatus.hidden:
      return (
        detail: 'Cancelada · cobrado $paid de $total',
        trailing: null,
        tone: ReceivableRowTone.muted,
        stamp: null,
      );
    case ReceivableStatus.active:
      if (view.isFullyPaid) {
        return (
          detail: 'Cobrado $paid de $total',
          trailing: 'Cobrado al 100%',
          tone: ReceivableRowTone.positive,
          stamp: null,
        );
      }
      return (
        detail: 'Cobrado $paid de $total',
        trailing: 'Falta \$${formatCurrency(view.remainingBalance)}',
        tone: ReceivableRowTone.warning,
        stamp: null,
      );
  }
}
