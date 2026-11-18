import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/config/supabase_config.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_theme.dart';
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
      setState(() => _walletCardsError = 'No se pudieron cargar las tarjetas de Wallet. Revisá la conexión.');
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
      ref.read(syncServiceProvider).syncNow(silent: true).catchError(
            (Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'wallet_shortcut.sync'),
          );
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
      if (!mounted) return;
      setState(() => _token = token as String);
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'wallet_shortcut.create_token');
      if (!mounted) return;
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
    final c = context.colors;
    final t = Theme.of(context).textTheme;
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Registrá un egreso automáticamente cada vez que pagás con Apple Wallet, sin abrir la app. '
              'Aparece en Egresos como "[Wallet]: comercio" en la siguiente sincronización.',
              style: t.bodyMedium?.copyWith(color: c.textMuted),
            ),
          ),
          const _SectionHeader('Conexión del atajo'),
          _Group(
            children: [
              _CopyRow(label: 'URL', value: _url, onCopy: () => _copy('URL', _url)),
              if (_token != null)
                _CopyRow(label: 'Token', value: _token!, onCopy: () => _copy('Token', _token!)),
              _ActionRow(
                icon: CupertinoIcons.lock,
                label: _token == null ? 'Generar token' : 'Generar otro token',
                loading: _loading,
                onTap: _loading ? null : _generate,
              ),
            ],
          ),
          _Footnote(
            _token != null
                ? 'Copialo ahora: no se vuelve a mostrar. Generar uno nuevo deja sin efecto el anterior.'
                : 'Generar un token nuevo deja sin efecto el anterior.',
            color: _token != null ? c.warning : null,
          ),
          if (_error != null) _InlineError(message: _error!, onRetry: _generate),
          _SectionHeader(
            'Tarjetas de Wallet',
            trailing: IconButton(
              icon: Icon(CupertinoIcons.arrow_clockwise, size: 20, color: c.accent),
              tooltip: 'Actualizar tarjetas de Wallet',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: _loadWalletCards,
            ),
          ),
          if (_walletCardsError != null)
            _InlineError(message: _walletCardsError!, onRetry: _loadWalletCards)
          else if (_walletCards == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (_walletCards!.isEmpty)
            _Footnote(
              'Todavía no hay tarjetas para asignar. Cuando llegue un pago con una tarjeta de Wallet que no se reconozca por nombre, '
              'va a aparecer acá para que la asignes una sola vez.',
            )
          else
            _Group(
              children: [
                for (final card in _walletCards!)
                  _WalletCardRow(card: card, targets: targets, onAssign: (t) => _assign(card, t)),
              ],
            ),
          const _SectionHeader('Configurar el atajo'),
          const _Group(
            children: [
              _Step(1, 'En Atajos → Automatización, abrí la automatización "Transaction" de Wallet y elegí "Run Immediately".'),
              _Step(2, 'Borrá la acción "Open URL" y agregá "Get Contents of URL" con la URL de arriba.'),
              _Step(3, 'Method: POST. En Headers agregá "Authorization" con valor "Bearer " seguido del token.'),
              _Step(4, 'Request Body: JSON, con tres campos de texto: amount, merchant y card.'),
              _Step(5, 'En cada campo tocá el valor, elegí "Shortcut Input" y seleccioná Amount, Merchant y Card respectivamente.'),
              _Step(6, 'Si el nombre de la tarjeta en Wallet no se parece al de Perfinance, el primer pago la deja en "Tarjetas de Wallet" para que la asignes.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, trailing == null ? 28 : 16, 0, trailing == null ? 8 : 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c.textMuted,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lista agrupada al estilo iOS: filas sobre `surface` con separadores finos.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, indent: 16, color: c.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color ?? context.colors.textMuted),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, size: 18, color: c.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.danger)),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.danger),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCardRow extends StatelessWidget {
  const _WalletCardRow({required this.card, required this.targets, required this.onAssign});
  final Map<String, dynamic> card;
  final List<DropdownMenuItem<String>> targets;
  final ValueChanged<String> onAssign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final assigned = card['payment_type'] == null
        ? null
        : '${card['payment_type']}|${card['payment_ref']}';
    // El medio asignado pudo borrarse o desactivarse: sin selección en ese caso.
    final value = targets.any((t) => t.value == assigned) ? assigned : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card['wallet_name'] as String, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.ink)),
          DropdownButton<String>(
            isExpanded: true,
            value: value,
            underline: const SizedBox.shrink(),
            dropdownColor: c.surface,
            icon: Icon(CupertinoIcons.chevron_up_chevron_down, size: 16, color: c.textMuted),
            hint: Text('Sin asignar: elegí a qué corresponde', style: TextStyle(color: c.warning)),
            items: targets,
            onChanged: (t) {
              if (t != null && t != value) onAssign(t);
            },
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, required this.onCopy});
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelLarge?.copyWith(color: c.ink)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: t.bodySmall?.copyWith(
                    color: c.textMuted,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(CupertinoIcons.doc_on_doc, color: c.accent),
            tooltip: 'Copiar $label',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.loading, required this.onTap});
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (loading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                else
                  Icon(icon, size: 20, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
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

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text('$number.', style: t.bodyMedium?.copyWith(color: c.textMuted, fontFeatures: kTabularFigures)),
          ),
          Expanded(child: Text(text, style: t.bodyMedium?.copyWith(color: c.ink))),
        ],
      ),
    );
  }
}
