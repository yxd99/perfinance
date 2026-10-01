import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:perfinance/features/savings/savings_provider.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configura el registro automático de egresos al pagar con Apple Wallet:
/// genera el token personal que usa el atajo de iOS para llamar a la edge
/// function `log-wallet-expense` sin abrir la app, y asigna las tarjetas de
/// Wallet que la función no pudo reconocer por nombre.
class WalletShortcutScreen extends ConsumerStatefulWidget {
  const WalletShortcutScreen({super.key});

  @override
  ConsumerState<WalletShortcutScreen> createState() => _WalletShortcutScreenState();
}

class _WalletShortcutScreenState extends ConsumerState<WalletShortcutScreen> {
  String? _token;
  bool _loading = false;
  String? _error;

  /// Filas de `wallet_cards` (solo en la nube); null mientras carga.
  List<Map<String, dynamic>>? _walletCards;
  String? _walletCardsError;

  @override
  void initState() {
    super.initState();
    _loadWalletCards();
  }

  Future<void> _loadWalletCards() async {
    try {
      final rows = await Supabase.instance.client
          .from('wallet_cards')
          .select()
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _walletCards = rows;
        _walletCardsError = null;
      });
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'wallet_shortcut.load_cards');
      if (!mounted) return;
      setState(() => _walletCardsError = 'No se pudieron cargar las tarjetas de Wallet.');
    }
  }

  /// [target] viene como `tipo|id`, el mismo valor que usa el selector.
  Future<void> _assign(Map<String, dynamic> card, String target) async {
    final parts = target.split('|');
    try {
      final fixed = await Supabase.instance.client.rpc(
        'assign_wallet_card',
        params: {
          'p_name_key': card['name_key'],
          'p_payment_type': parts[0],
          'p_payment_ref': parts[1],
        },
      ) as int;
      await _loadWalletCards();
      // Baja los egresos que la nube acaba de mover a la tarjeta correcta.
      ref.read(syncServiceProvider).syncNow(silent: true).catchError((_) {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fixed == 0
                ? 'Tarjeta asignada'
                : 'Tarjeta asignada. Egresos corregidos: $fixed',
          ),
        ),
      );
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'wallet_shortcut.assign_card');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo asignar la tarjeta. Intentá de nuevo.')),
      );
    }
  }

  String get _url => '${SupabaseConfig.url}/functions/v1/log-wallet-expense';

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await Supabase.instance.client.rpc(
        'create_shortcut_token',
        params: {'p_utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes},
      );
      setState(() => _token = token as String);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'wallet_shortcut.create_token');
      setState(() => _error = 'No se pudo generar el token. Revisá la conexión e intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ref.watch(activeCreditCardsListProvider).valueOrNull ?? const [];
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull ?? const [];
    final targets = <DropdownMenuItem<String>>[
      for (final c in cards)
        DropdownMenuItem(value: 'credit_card|${c.id}', child: Text('Tarjeta: ${c.alias}')),
      for (final m in methods)
        DropdownMenuItem(value: 'payment_method|${m.id}', child: Text('Ahorro: ${m.name}')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Apple Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Registrá un egreso automáticamente cada vez que pagás con Apple Wallet, sin abrir la app. '
            'Aparece en Egresos como "[Wallet]: comercio" en la siguiente sincronización.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _CopyTile(label: 'URL', value: _url, onCopy: () => _copy('URL', _url)),
          const SizedBox(height: 8),
          if (_token != null) ...[
            _CopyTile(
              label: 'Token',
              value: _token!,
              onCopy: () => _copy('Token', _token!),
            ),
            const SizedBox(height: 4),
            Text(
              'Copialo ahora: no se vuelve a mostrar.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.key),
            label: Text(_token == null ? 'Generar token' : 'Generar otro token'),
          ),
          const SizedBox(height: 4),
          Text(
            'Generar un token nuevo deja sin efecto el anterior.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Tarjetas de Wallet', style: theme.textTheme.titleMedium)),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: _loadWalletCards,
              ),
            ],
          ),
          if (_walletCardsError != null)
            Text(_walletCardsError!, style: TextStyle(color: theme.colorScheme.error))
          else if (_walletCards == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_walletCards!.isEmpty)
            Text(
              'Cuando llegue un pago con una tarjeta de Wallet que no se reconozca por nombre, '
              'va a aparecer acá para que la asignes una sola vez.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final card in _walletCards!)
              _WalletCardTile(card: card, targets: targets, onAssign: (t) => _assign(card, t)),
          const SizedBox(height: 24),
          Text('Configurar el atajo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _Step(1, 'En Atajos → Automatización, abrí la automatización "Transaction" de Wallet y elegí "Run Immediately".'),
          const _Step(2, 'Borrá la acción "Open URL" y agregá "Get Contents of URL" con la URL de arriba.'),
          const _Step(3, 'Method: POST. En Headers agregá "Authorization" con valor "Bearer " seguido del token.'),
          const _Step(4, 'Request Body: JSON, con tres campos de texto: amount, merchant y card.'),
          const _Step(5, 'En cada campo tocá el valor, elegí "Shortcut Input" y seleccioná Amount, Merchant y Card respectivamente.'),
          const _Step(6, 'Si el nombre de la tarjeta en Wallet no se parece al de Perfinance, el primer pago la deja en "Tarjetas de Wallet" para que la asignes.'),
        ],
      ),
    );
  }
}

class _WalletCardTile extends StatelessWidget {
  const _WalletCardTile({required this.card, required this.targets, required this.onAssign});
  final Map<String, dynamic> card;
  final List<DropdownMenuItem<String>> targets;
  final ValueChanged<String> onAssign;

  @override
  Widget build(BuildContext context) {
    final assigned = card['payment_type'] == null
        ? null
        : '${card['payment_type']}|${card['payment_ref']}';
    // El medio asignado pudo borrarse o desactivarse: sin selección en ese caso.
    final value = targets.any((t) => t.value == assigned) ? assigned : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card['wallet_name'] as String, style: Theme.of(context).textTheme.titleSmall),
            DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('Sin asignar: elegí a qué corresponde'),
              items: targets,
              onChanged: (t) {
                if (t != null && t != value) onAssign(t);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  const _CopyTile({required this.label, required this.value, required this.onCopy});
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(label),
        subtitle: Text(value, style: const TextStyle(fontFamily: 'monospace')),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copiar $label',
          onPressed: onCopy,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('$number.')),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
