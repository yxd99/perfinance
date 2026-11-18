import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/features/automatic_payments/automatic_payment_form_screen.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';

/// Pantalla que muestra los pagos automáticos registrados a una tarjeta o cuenta.
class DashboardAccountAutomaticPaymentsScreen extends ConsumerWidget {
  const DashboardAccountAutomaticPaymentsScreen({
    super.key,
    required this.alias,
    required this.paymentType,
    required this.paymentRef,
  });

  final String alias;
  final String paymentType;
  final String paymentRef;

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(automaticPaymentsListProvider);
    final hideValues = ref.watch(hideValuesProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(alias),
      ),
      body: asyncList.when(
        data: (all) {
          final list = all
              .where((p) => p.paymentType == paymentType && p.paymentRef == paymentRef)
              .toList()
            ..sort((a, b) => a.description.compareTo(b.description));

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_2_circlepath, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Sin pagos automáticos en esta cuenta',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final total = list.fold<double>(0, (s, p) => s + p.amount);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Total estimado: \$${formatCurrencyDisplay(total, hideValues)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.accent,
                      ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.colors.accentSoft,
                          child: Icon(CupertinoIcons.arrow_2_circlepath, color: context.colors.accent, size: 22),
                        ),
                        title: Text(p.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '\$${formatCurrencyDisplay(p.amount, hideValues)} · Día ${p.paymentDayOfMonth} · ${_capitalize(p.frequency)}',
                        ),
                        trailing: const Icon(CupertinoIcons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AutomaticPaymentFormScreen(edit: p),
                            ),
                          ).then((_) {
                            ref.invalidate(automaticPaymentsListProvider);
                            ref.invalidate(dashboardAutomaticPaymentsSummaryProvider);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar los pagos automáticos',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
