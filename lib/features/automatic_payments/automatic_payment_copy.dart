import 'package:perfinance/data/models/automatic_payment.dart';

const _frequencyLabels = <String, String>{
  'mensual': 'Mensual',
  'trimestral': 'Trimestral',
  'semestral': 'Semestral',
  'anual': 'Anual',
};

/// Frecuencias guardadas, en el orden en que se ofrecen en el formulario.
const automaticPaymentFrequencies = <String>['mensual', 'trimestral', 'semestral', 'anual'];

/// Frecuencia guardada (`mensual`, `anual`...) como texto de interfaz.
String frequencyLabel(String frequency) => _frequencyLabels[frequency] ?? frequency;

bool isAutomaticPaymentPaused(AutomaticPayment p) => p.status == 'paused';

/// Línea de estado bajo la descripción: «Día 15 · Mensual · Visa», con
/// «En pausa» adelante cuando el pago no está generando egresos.
String automaticPaymentStatusLine(AutomaticPayment p, {required String accountName}) => [
  if (isAutomaticPaymentPaused(p)) 'En pausa',
  'Día ${p.paymentDayOfMonth}',
  frequencyLabel(p.frequency),
  accountName,
].join(' · ');
