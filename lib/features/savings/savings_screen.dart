import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/summary_total_bar.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(paymentMethodsListProvider);
    return asyncList.when(
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: Icons.savings_outlined,
            message: 'No hay medios de pago. Añade uno.',
            actionLabel: 'Añadir medio',
            onAction: () => _openForm(context, ref),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SummaryTotalBar(
                label: 'Medios de pago',
                amount: '${list.length}',
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: list.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.icon(
                        onPressed: () => _openForm(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir medio de pago'),
                      ),
                    );
                  }
                  final pm = list[i - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(pm.name),
                      subtitle: Text(pm.type),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentMethodFormScreen(edit: pm),
                          ),
                        ),
                      ),
                      onLongPress: () => _delete(context, ref, pm),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorState(
        message: UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.savingsLoadFailed),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodFormScreen()),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PaymentMethod pm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${pm.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(paymentMethodRepositoryProvider).delete(pm.id);
    ref.invalidate(paymentMethodsListProvider);
    ref.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
  }
}
