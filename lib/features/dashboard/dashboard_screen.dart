import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/dashboard/dashboard_account_automatic_payments_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_account_expenses_screen.dart';
import 'package:perfinance/features/dashboard/dashboard_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_provider.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_screen.dart';
import 'package:perfinance/services/dashboard_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(creditCardsListProvider);
    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final asyncDebt = ref.watch(dashboardDebtProvider);
    final asyncUsage = ref.watch(dashboardUsageProvider);
    final asyncComparison = ref.watch(dashboardComparisonProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideValues = ref.watch(hideValuesProvider).value ?? false;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardDebtProvider);
        ref.invalidate(hasActiveDebtSourcesProvider);
        ref.invalidate(dashboardAutomaticPaymentsSummaryProvider);
        ref.invalidate(overdueAutomaticPaymentsProvider);
        ref.invalidate(dashboardUsageProvider);
          ref.invalidate(dashboardComparisonProvider);
        ref.invalidate(dashboardMinPaymentSummaryProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMonthSelector(context, ref),
          const SizedBox(height: 16),
          ref.watch(hasActiveDebtSourcesProvider).when(
            data: (hasActive) {
              if (!hasActive) return const SizedBox.shrink();
              return asyncDebt.when(
                data: (debt) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: _SectionHeader(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Deuda total',
                      isDark: isDark,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DebtHeroCard(amount: debt.total, isDark: isDark, hideValues: hideValues),
                            if (debt.items.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ExpansionTile(
                                key: const PageStorageKey('debt_detalle'),
                                initiallyExpanded: true,
                                tilePadding: const EdgeInsets.symmetric(vertical: 8),
                                childrenPadding: EdgeInsets.zero,
                                backgroundColor: Colors.transparent,
                                collapsedBackgroundColor: Colors.transparent,
                                title: Text(
                                  'Detalle',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppThemeColors.primaryGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                iconColor: AppThemeColors.primaryGreen,
                                collapsedIconColor: AppThemeColors.primaryGreen,
                                children: [
                                  _DebtBreakdownSection(items: debt.items, isDark: isDark, hideValues: hideValues),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ref.watch(hasActiveDebtSourcesProvider).when(
            data: (hasActive) => hasActive ? const SizedBox(height: 12) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ref.watch(overdueAutomaticPaymentsProvider).when(
            data: (overdue) {
              if (overdue.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.amber.withValues(alpha: isDark ? 0.18 : 0.15),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AutomaticPaymentsScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              overdue.length == 1
                                  ? 'Tenés 1 pago automático atrasado sin procesar'
                                  : 'Tenés ${overdue.length} pagos automáticos atrasados sin procesar',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ref.watch(dashboardAutomaticPaymentsSummaryProvider).when(
            data: (summary) {
              if (summary.byAccount.isEmpty) return const SizedBox.shrink();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: _SectionHeader(
                    icon: Icons.autorenew,
                    title: 'Pagos automáticos del mes',
                    isDark: isDark,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total estimado',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                                Text(
                                  '\$${formatCurrencyDisplay(summary.totalPerMonth, hideValues)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppThemeColors.primaryGreen,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Por cuenta',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                          ),
                          const SizedBox(height: 6),
                          ...summary.byAccount.map(
                            (a) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: (a.isCreditCard ? AppThemeColors.primaryGreen : Colors.blue).withValues(alpha: isDark ? 0.4 : 0.15),
                                  child: Icon(
                                    a.isCreditCard ? Icons.credit_card : Icons.savings,
                                    color: a.isCreditCard ? AppThemeColors.primaryGreen : Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                title: Text(a.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                                trailing: Text(
                                  '\$${formatCurrencyDisplay(a.amount, hideValues)}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DashboardAccountAutomaticPaymentsScreen(
                                        alias: a.alias,
                                        paymentType: a.paymentType,
                                        paymentRef: a.paymentRef,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ref.watch(dashboardAutomaticPaymentsSummaryProvider).when(
            data: (summary) => summary.byAccount.isNotEmpty ? const SizedBox(height: 12) : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: _SectionHeader(
                icon: Icons.credit_card,
                title: 'Uso por tarjeta',
                isDark: isDark,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ref.watch(dashboardMinPaymentSummaryProvider).when(
                    data: (minSummary) => asyncUsage.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const Padding(padding: EdgeInsets.all(8), child: Text('Sin tarjetas'));
                        }
                        final showTotalMin = minSummary.totalPending > 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showTotalMin) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total pago mínimo pendiente',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                    ),
                                    Text(
                                      '\$${formatCurrencyDisplay(minSummary.totalPending, hideValues)}',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppThemeColors.primaryGreen,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            ...list.map((u) {
                              final minPending = minSummary.pendingByCard[u.cardId];
                              final showMinPending = minPending != null && minPending > 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.15),
                                    child: Icon(Icons.receipt_long, color: AppThemeColors.primaryGreen, size: 22),
                                  ),
                                  title: Text(u.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${u.count} veces · \$${formatCurrencyDisplay(u.totalAmount, hideValues)}'),
                                      if (showMinPending)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Pago mín. pendiente: \$${formatCurrencyDisplay(minPending, hideValues)}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: AppThemeColors.primaryGreen,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DashboardAccountExpensesScreen(
                                          alias: u.alias,
                                          paymentType: 'credit_card',
                                          paymentRef: u.cardId,
                                          month: selectedMonth,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }),
                          ],
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.dashboardLoadFailed),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    loading: () => asyncUsage.when(
                      data: (list) => list.isEmpty
                          ? const Padding(padding: EdgeInsets.all(8), child: Text('Sin tarjetas'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: list
                                  .map((u) => Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.15),
                                            child: Icon(Icons.receipt_long, color: AppThemeColors.primaryGreen, size: 22),
                                          ),
                                          title: Text(u.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          subtitle: Text('${u.count} veces · \$${formatCurrencyDisplay(u.totalAmount, hideValues)}'),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DashboardAccountExpensesScreen(
                                                  alias: u.alias,
                                                  paymentType: 'credit_card',
                                                  paymentRef: u.cardId,
                                                  month: selectedMonth,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ))
                                  .toList(),
                            ),
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.dashboardLoadFailed),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    error: (_, __) => asyncUsage.when(
                      data: (list) => list.isEmpty
                          ? const Padding(padding: EdgeInsets.all(8), child: Text('Sin tarjetas'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: list
                                  .map((u) => Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.15),
                                            child: Icon(Icons.receipt_long, color: AppThemeColors.primaryGreen, size: 22),
                                          ),
                                          title: Text(u.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          subtitle: Text('${u.count} veces · \$${formatCurrencyDisplay(u.totalAmount, hideValues)}'),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DashboardAccountExpensesScreen(
                                                  alias: u.alias,
                                                  paymentType: 'credit_card',
                                                  paymentRef: u.cardId,
                                                  month: selectedMonth,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ))
                                  .toList(),
                            ),
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.dashboardLoadFailed),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: _SectionHeader(
                icon: Icons.compare_arrows,
                title: 'Comparativa mes actual vs anterior',
                isDark: isDark,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: asyncComparison.when(
                    data: (list) => list.isEmpty
                        ? const Padding(padding: EdgeInsets.all(8), child: Text('Sin tarjetas'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: list
                                .map((c) {
                                  final isEqual = c.percentChange == null || c.percentChange! < 0.5;
                                  final isIncrease = c.isIncrease && !isEqual;
                                  final isDecrease = !c.isIncrease && !isEqual;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: isEqual
                                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: isDark ? 0.2 : 0.12)
                                            : (isIncrease ? Colors.red : AppThemeColors.primaryGreen).withValues(alpha: isDark ? 0.4 : 0.15),
                                        child: Icon(
                                          isEqual ? Icons.drag_handle : (isIncrease ? Icons.trending_up : Icons.trending_down),
                                          color: isEqual
                                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                              : (isIncrease ? Colors.red : AppThemeColors.primaryGreen),
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(c.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'Este mes: \$${formatCurrencyDisplay(c.thisMonth, hideValues)} · Anterior: \$${formatCurrencyDisplay(c.lastMonth, hideValues)}',
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isEqual
                                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: isDark ? 0.15 : 0.08)
                                              : (isIncrease ? Theme.of(context).colorScheme.error : AppThemeColors.primaryGreen).withValues(alpha: isDark ? 0.25 : 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isEqual ? '=' : '${(c.percentChange ?? 0).toStringAsFixed(0)}% ${isIncrease ? "↑" : "↓"}',
                                          style: TextStyle(
                                            color: isEqual
                                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                                                : (isIncrease ? Theme.of(context).colorScheme.error : AppThemeColors.primaryGreen),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        UserFriendlyErrors.fromAsyncError(e, UserFriendlyErrors.dashboardLoadFailed),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  Widget _buildMonthSelector(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDashboardMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth = selected.year == now.year && selected.month == now.month;
    final label = '${_monthNames[selected.month - 1]} ${selected.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final prev = selected.month == 1
                    ? DateTime(selected.year - 1, 12, 1)
                    : DateTime(selected.year, selected.month - 1, 1);
                ref.read(selectedDashboardMonthProvider.notifier).state = prev;
              },
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(now.year, now.month + 1),
                  );
                  if (picked != null) {
                    ref.read(selectedDashboardMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
                  }
                },
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentMonth
                  ? null
                  : () {
                      final next = selected.month == 12
                          ? DateTime(selected.year + 1, 1, 1)
                          : DateTime(selected.year, selected.month + 1, 1);
                      if (next.year < now.year || (next.year == now.year && next.month <= now.month)) {
                        ref.read(selectedDashboardMonthProvider.notifier).state = next;
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtHeroCard extends StatelessWidget {
  const _DebtHeroCard({required this.amount, required this.isDark, required this.hideValues});

  final double amount;
  final bool isDark;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final hasDebt = amount > 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: hasDebt ? AppThemeColors.debtGradient : AppThemeColors.primaryGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasDebt ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Deuda total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '\$${formatCurrencyDisplay(amount, hideValues)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtBreakdownSection extends StatelessWidget {
  const _DebtBreakdownSection({required this.items, required this.isDark, required this.hideValues});

  final List<DebtBreakdownItem> items;
  final bool isDark;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _DebtBreakdownTile(item: items[i], isDark: isDark, hideValues: hideValues),
          if (i < items.length - 1)
            const Divider(height: 1),
        ],
      ],
    );
  }
}

class _DebtBreakdownTile extends StatelessWidget {
  const _DebtBreakdownTile({required this.item, required this.isDark, required this.hideValues});

  final DebtBreakdownItem item;
  final bool isDark;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            item.isCreditCard ? Icons.credit_card : Icons.receipt_long,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${formatCurrencyDisplay(item.balance, hideValues)}',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.isDark});

  final IconData icon;
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppThemeColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.primaryGreen.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ],
    );
  }
}
