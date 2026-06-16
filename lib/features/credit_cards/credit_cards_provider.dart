import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';

final creditCardsListProvider = FutureProvider<List<CreditCard>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(creditCardRepositoryProvider).getAll(user.id);
});
