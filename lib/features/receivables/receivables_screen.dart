import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/widgets/row_actions_button.dart';
import 'package:perfinance/core/widgets/inset_add_row.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/core/widgets/app_empty_state.dart';
import 'package:perfinance/core/widgets/app_error_state.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/core/widgets/paid_stamp.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/features/receivables/receivable_actions.dart';
import 'package:perfinance/features/receivables/receivable_detail_screen.dart';
import 'package:perfinance/features/receivables/receivable_form_screen.dart';
import 'package:perfinance/features/receivables/receivable_row_status.dart';
import 'package:perfinance/features/receivables/receivables_provider.dart';
import 'package:perfinance/features/receivables/widgets/inset_list_group.dart';

final receivableListFilterProvider = StateProvider<ReceivableListFilter>((ref) => ReceivableListFilter.active);

const _filterLabels = <ReceivableListFilter, String>{
  ReceivableListFilter.active: 'Activas',
  ReceivableListFilter.settled: 'Cobradas',
  ReceivableListFilter.all: 'Todas',
};

/// Cuerpo de «Me deben». El Scaffold y la barra los pone el hub «Más».
class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(receivableListFilterProvider);
    final asyncList = ref.watch(filteredReceivablesProvider(filter));
    final asyncTotal = ref.watch(receivablesTotalOutstandingProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<ReceivableListFilter>(
              groupValue: filter,
              backgroundColor: c.track,
              thumbColor: c.surface,
              children: {
                for (final e in _filterLabels.entries)
                  e.key: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      e.value,
                      style: TextStyle(color: c.ink, fontWeight: filter == e.key ? FontWeight.w600 : FontWeight.w500),
                    ),
                  ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                ref.read(receivableListFilterProvider.notifier).state = value;
              },
            ),
          ),
        ),
        Expanded(
          child: asyncList.when(
            skipLoadingOnReload: true,
            data: (views) {
              if (views.isEmpty) {
                final settledTab = filter == ReceivableListFilter.settled;
                return AppEmptyState(
                  icon: CupertinoIcons.person_2,
                  message: settledTab
                      ? 'Todavía no saldaste ningún cobro. Cuando alguien te pague todo, queda aquí.'
                      : 'Nadie te debe dinero por ahora.',
                  actionLabel: settledTab ? null : 'Agregar deudor',
                  onAction: settledTab ? null : () => _openForm(context),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // Total tranquilo arriba de la lista, como en Deudas y Egresos.
                  asyncTotal.when(
                    data: (total) => Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                      child: Text.rich(
                        TextSpan(
                          text: 'Total por cobrar: ',
                          style: TextStyle(color: c.textMuted),
                          children: [
                            TextSpan(
                              text: '\$${formatCurrency(total)}',
                              style: TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontFeatures: kTabularFigures),
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  InsetListGroup(
                    children: [
                      for (final view in views)
                        _ReceivableRow(
                          view: view,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReceivableDetailScreen(receivable: view.receivable)),
                          ),
                          onDelete: () => confirmAndDeleteReceivable(context, view.receivable),
                        ),
                      InsetAddRow(label: 'Agregar deudor', onTap: () => _openForm(context)),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => AppErrorState(
              message: UserFriendlyErrors.fromAsyncError(e, 'No se pudo cargar lo que te deben. Prueba de nuevo.'),
              onRetry: () => ref.invalidate(receivablesListProvider),
            ),
          ),
        ),
      ],
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivableFormScreen()));
  }
}

/// Fila de un cobro. Tocar abre el detalle (ahí se registra o se cobra todo);
/// deslizar a la izquierda elimina, con confirmación. VoiceOver tiene la
/// misma acción de eliminar.
class _ReceivableRow extends StatelessWidget {
  const _ReceivableRow({required this.view, required this.onTap, required this.onDelete});

  final ReceivableView view;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final r = view.receivable;
    final status = receivableRowStatus(view);
    final isActive = r.status == ReceivableStatus.active;
    final toneColor = switch (status.tone) {
      ReceivableRowTone.warning => c.warning,
      ReceivableRowTone.positive => c.positive,
      ReceivableRowTone.muted => c.textMuted,
    };
    final progress = r.totalAmount > 0 ? (view.totalPaid / r.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;

    final row = InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.debtorName,
                      style: t.bodyLarge?.copyWith(color: isActive ? c.ink : c.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.description?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.description!.trim(),
                        style: t.bodySmall?.copyWith(color: c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      status.detail,
                      style: t.bodySmall?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures),
                      maxLines: 2,
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 6),
                      ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: c.track,
                          valueColor: AlwaysStoppedAnimation(c.accent),
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (status.stamp != null)
                PaidStamp(label: status.stamp!)
              // Sin Flexible: con flex el monto recibía media fila y quedaba
              // flotando en el centro; así va pegado al chevron, como en las
              // otras listas.
              else if (status.trailing != null)
                Text(
                  status.trailing!,
                  textAlign: TextAlign.right,
                  style: t.titleSmall?.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              RowActionsButton(
                title: r.debtorName,
                actions: [
                  RowAction(label: 'Ver detalle', icon: CupertinoIcons.info_circle, onSelected: onTap),
                  RowAction(label: 'Eliminar', icon: CupertinoIcons.trash, destructive: true, onSelected: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Eliminar deudor'): onDelete,
      },
      child: Dismissible(
        key: ValueKey('receivable-${r.id}'),
        direction: DismissDirection.endToStart,
        // Se borra dentro de la confirmación: si falla, la fila vuelve a su lugar.
        confirmDismiss: (_) => onDelete(),
        background: Container(
          color: c.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Icon(CupertinoIcons.trash, color: c.onDanger, semanticLabel: 'Eliminar'),
        ),
        child: row,
      ),
    );
  }
}
