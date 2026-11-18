import 'package:shared_preferences/shared_preferences.dart';

/// Última cuenta con la que se registró un egreso: el registro rápido la
/// preselecciona para que el caso común sea monto y guardar.
class LastAccount {
  const LastAccount({required this.paymentType, required this.paymentRef});

  /// `credit_card` o `payment_method`, como en `Expense.paymentType`.
  final String paymentType;
  final String paymentRef;

  bool get isCard => paymentType == 'credit_card';

  @override
  bool operator ==(Object other) =>
      other is LastAccount && other.paymentType == paymentType && other.paymentRef == paymentRef;

  @override
  int get hashCode => Object.hash(paymentType, paymentRef);
}

/// Devuelve [saved] solo si esa cuenta todavía se puede elegir: una tarjeta
/// activa o un medio de pago que siga existiendo. Si no, no se preselecciona.
LastAccount? resolveLastAccount(
  LastAccount? saved, {
  required Set<String> activeCardIds,
  required Set<String> methodIds,
}) {
  if (saved == null) return null;
  final ids = saved.isCard ? activeCardIds : methodIds;
  return ids.contains(saved.paymentRef) ? saved : null;
}

/// Guarda la última cuenta en SharedPreferences (preferencia del dispositivo,
/// no se sincroniza).
class LastAccountStore {
  static const _typeKey = 'last_expense_payment_type';
  static const _refKey = 'last_expense_payment_ref';

  static Future<LastAccount?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(_typeKey);
    final ref = prefs.getString(_refKey);
    if (type == null || ref == null || ref.isEmpty) return null;
    return LastAccount(paymentType: type, paymentRef: ref);
  }

  static Future<void> save(LastAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, account.paymentType);
    await prefs.setString(_refKey, account.paymentRef);
  }
}
