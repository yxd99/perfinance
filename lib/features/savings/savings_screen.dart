import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';
import 'package:perfinance/features/accounts/account_hue_provider.dart';
import 'package:perfinance/features/savings/payment_method_form_screen.dart';
import 'package:perfinance/features/savings/payment_method_type.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/sync_service.dart';

/// Medios de pago (efectivo, débito, otro). Se abre desde «Más», que pone el
/// Scaffold y la barra; acá va solo el cuerpo.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(paymentMethodsListProvider);
    return asyncList.when(
      data: (list) => list.isEmpty
          ? _SavingsMessage(
              icon: CupertinoIcons.money_dollar_circle,
              message: 'Todavía no tenés medios de pago. Agregá efectivo, una débito u otro para registrar egresos que no van a tarjeta.',
              actionLabel: 'Agregar medio de pago',
              onAction: () => _openForm(context),
            )
          : _SavingsList(methods: list),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => _SavingsMessage(
        icon: CupertinoIcons.exclamationmark_triangle,
        message: 'No se pudieron cargar los medios de pago.',
        actionLabel: 'Reintentar',
        onAction: () => ref.invalidate(paymentMethodsListProvider),
      ),
    );
  }
}

void _openForm(BuildContext context, {PaymentMethod? edit}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PaymentMethodFormScreen(edit: edit)),
  );
}

class _SavingsList extends ConsumerWidget {
  const _SavingsList({required this.methods});

  final List<PaymentMethod> methods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              'MEDIOS DE PAGO',
              style: t.labelMedium?.copyWith(color: c.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pm in methods) ...[
                _MethodRow(method: pm),
                Divider(height: 1, thickness: 0.5, indent: 62, color: c.divider),
              ],
              _AddRow(onTap: () => _openForm(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Deslizá un medio hacia la izquierda para eliminarlo.',
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _MethodRow extends ConsumerWidget {
  const _MethodRow({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final typeLabel = paymentMethodTypeLabel(method.type);
    return Dismissible(
      key: ValueKey(method.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(CupertinoIcons.trash, color: c.onDanger),
      ),
      confirmDismiss: (_) => _confirmDelete(context, method),
      onDismissed: (_) => _delete(context, method),
      child: Semantics(
        button: true,
        label: '${method.name}, $typeLabel',
        hint: 'Editar',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => _openForm(context, edit: method),
          onLongPress: () async {
            if (await _confirmDelete(context, method) && context.mounted) {
              await _delete(context, method);
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 34,
                      height: 22,
                      decoration: BoxDecoration(
                        color: ref.accountHue(context, method.id),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(method.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyLarge?.copyWith(color: c.ink)),
                        Text(typeLabel, style: t.bodySmall?.copyWith(color: c.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_forward, size: 18, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(width: 34, child: Icon(CupertinoIcons.add, size: 20, color: c.accent)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Agregar medio de pago',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío o de error: un ícono quieto, el mensaje y una acción.
class _SavingsMessage extends StatelessWidget {
  const _SavingsMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.textMuted),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, PaymentMethod pm) async {
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text('¿Eliminar «${pm.name}»?'),
      content: const Text('No se puede deshacer.'),
      actions: [
        adaptiveDialogAction(ctx, label: 'Cancelar', onPressed: () => Navigator.pop(ctx, false)),
        adaptiveDialogAction(ctx, label: 'Eliminar', destructive: true, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return ok == true;
}

/// Toma el contenedor y el messenger antes de esperar: la fila deslizada ya no
/// existe cuando termina el borrado.
Future<void> _delete(BuildContext context, PaymentMethod pm) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await container.read(paymentMethodRepositoryProvider).delete(pm.id);
  } catch (e, st) {
    ErrorReporter.capture(e, st, operation: 'savings.delete', details: {'id': pm.id});
    messenger?.showSnackBar(const SnackBar(content: Text('No se pudo eliminar el medio de pago. Intentá de nuevo.')));
  }
  container.invalidate(paymentMethodsListProvider);
  container.read(syncServiceProvider).pushPendingIfOnline().catchError((_) {});
}

/// Botón de diálogo con la forma de la plataforma: acción de Cupertino en iOS
/// y macOS, TextButton en el resto.
Widget adaptiveDialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool destructive = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoDialogAction(isDestructiveAction: destructive, onPressed: onPressed, child: Text(label));
  }
  return TextButton(
    onPressed: onPressed,
    style: destructive ? TextButton.styleFrom(foregroundColor: context.colors.danger) : null,
    child: Text(label),
  );
}
