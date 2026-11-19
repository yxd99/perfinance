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

/// Cantidad de tonos en la paleta de billetes ([AppColors.noteHues]).
const noteHueCount = 5;

/// Aplica los colores que el usuario eligió sobre los automáticos. Una cuenta
/// sin elección (null) o con un valor fuera de la paleta queda como estaba.
Map<String, int> applyChosenHueSlots(Map<String, int> auto, Map<String, int?> chosen) {
  final slots = Map<String, int>.of(auto);
  chosen.forEach((id, slot) {
    if (slot != null && slot >= 0 && slot < noteHueCount) slots[id] = slot;
  });
  return slots;
}
