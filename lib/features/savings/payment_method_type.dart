/// Tipos de medio de pago que guarda el formulario. Hay filas viejas con
/// `cash` y `debit`, que se leen igual pero no se reescriben solas.
const paymentMethodFormTypes = <String, String>{
  'efectivo': 'Efectivo',
  'debito': 'Débito',
  'other': 'Otro',
};

/// Valor del formulario que corresponde a un tipo guardado (incluidos los
/// heredados). Un valor desconocido cae en `other`.
String paymentMethodFormType(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'efectivo' || 'cash' => 'efectivo',
    'debito' || 'débito' || 'debit' => 'debito',
    _ => 'other',
  };
}

/// Nombre del tipo para mostrar. Nunca devuelve el valor crudo.
String paymentMethodTypeLabel(String raw) => paymentMethodFormTypes[paymentMethodFormType(raw)]!;
