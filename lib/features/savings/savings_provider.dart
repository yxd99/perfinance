import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

final paymentMethodsListProvider = FutureProvider<List<PaymentMethod>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(paymentMethodRepositoryProvider).getAll(user.id);
});
