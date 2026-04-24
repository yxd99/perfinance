import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/repositories/card_payment_repository.dart';
import 'package:perfinance/features/credit_cards/card_payment_date_filter.dart';

final selectedCardPaymentDateFilterProvider = StateProvider.family<CardPaymentDateFilter, String>(
  (ref, cardId) => CardPaymentDateFilter.currentMonth,
);

final cardPaymentsByCardProvider = FutureProvider.autoDispose.family<List<CardPayment>, String>((ref, cardId) async {
  return ref.read(cardPaymentRepositoryProvider).getByCardId(cardId);
});

final filteredCardPaymentsByCardProvider =
    FutureProvider.autoDispose.family<List<CardPayment>, String>((ref, cardId) async {
  final list = await ref.watch(cardPaymentsByCardProvider(cardId).future);
  final filter = ref.watch(selectedCardPaymentDateFilterProvider(cardId));
  final range = filter.rangeOrNow;
  final rangeStartDay = DateTime(range.start.year, range.start.month, range.start.day);
  final rangeEndDay = DateTime(range.end.year, range.end.month, range.end.day);

  return list.where((p) {
    final dLocal = p.date.toLocal();
    final payDay = DateTime(dLocal.year, dLocal.month, dLocal.day);
    return !payDay.isBefore(rangeStartDay) && !payDay.isAfter(rangeEndDay);
  }).toList();
});

