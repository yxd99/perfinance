import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formato de miles con punto (ej. 1.500.000).
String formatCurrency(num value) {
  if (value.isNaN || value.isInfinite) return '0';
  final int v = value.round();
  if (v == 0) return '0';
  final String s = v.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return v < 0 ? '-${buffer.toString()}' : buffer.toString();
}

/// Formato para mostrar en UI: si [hideValues] es true devuelve placeholder, si no [formatCurrency].
String formatCurrencyDisplay(num value, bool hideValues) {
  if (hideValues) return '••••••';
  return formatCurrency(value);
}

/// Parsea string con formato de moneda a double (quita puntos).
double? parseCurrency(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits)?.toDouble();
}

/// Formateador para usar en inputFormatters: muestra miles con punto al escribir.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = formatCurrency(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Campo de texto con formato de moneda en tiempo real.
class CurrencyTextField extends StatelessWidget {
  const CurrencyTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.validator,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CurrencyInputFormatter()],
      decoration: decoration ?? const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
      validator: validator ??
          (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa el monto';
            final val = parseCurrency(v);
            if (val == null || val <= 0) return 'Monto inválido';
            return null;
          },
    );
  }
}
