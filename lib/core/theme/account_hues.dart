/// Posición de cada cuenta en la paleta de billetes ([AppColors.noteHues]).
///
/// Se ordena por fecha de creación para que una cuenta nueva no le cambie el
/// color a las existentes y para que las primeras cinco nunca se repitan.
/// Las cuentas sin fecha van al final; el id desempata.
Map<String, int> assignHueSlots(Iterable<({String id, String? createdAt})> accounts) {
  final sorted = accounts.toList()
    ..sort((a, b) {
      final ac = a.createdAt, bc = b.createdAt;
      if (ac != bc) {
        if (ac == null) return 1;
        if (bc == null) return -1;
        final byDate = ac.compareTo(bc);
        if (byDate != 0) return byDate;
      }
      return a.id.compareTo(b.id);
    });
  final slots = <String, int>{};
  for (final account in sorted) {
    slots.putIfAbsent(account.id, () => slots.length);
  }
  return slots;
}
