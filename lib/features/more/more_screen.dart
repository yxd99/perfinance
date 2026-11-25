import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:perfinance/core/config/features.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/providers/hide_values_provider.dart';
import 'package:perfinance/core/theme/app_colors.dart';
import 'package:perfinance/core/utils/user_friendly_errors.dart';
import 'package:perfinance/data/database/database_provider.dart';
import 'package:perfinance/features/auth/account_deletion_service.dart';
import 'package:perfinance/features/auth/account_service.dart';
import 'package:perfinance/features/auth/auth_service.dart';
import 'package:perfinance/features/more/delete_account_dialog.dart';
import 'package:perfinance/features/more/account_screen.dart';
import 'package:perfinance/features/automatic_payments/automatic_payments_screen.dart';
import 'package:perfinance/features/credit_cards/credit_cards_screen.dart';
import 'package:perfinance/features/onboarding/onboarding_screen.dart';
import 'package:perfinance/features/receivables/receivables_screen.dart';
import 'package:perfinance/features/savings/savings_screen.dart';
import 'package:perfinance/services/sync_service.dart';

/// Pestaña «Más»: secciones secundarias, ajustes y cierre de sesión, como una
/// lista agrupada de Ajustes de iOS.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  /// Las pantallas que eran pestañas no tienen barra propia: aquí se les da
  /// Scaffold y título al abrirlas.
  void _openSection(String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
      ),
    );
  }

  /// Cerrar sesión borra la base local: antes se sube lo pendiente y, si algo
  /// no pudo subirse, se pide confirmación porque esos cambios se perderían.
  Future<void> _logout() async {
    final syncService = ref.read(syncServiceProvider);
    final pending = await syncService.pushAndCountPending();
    if (!mounted) return;
    if (pending > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambios sin sincronizar'),
          content: Text(
            pending == 1
                ? 'Hay 1 cambio que no se pudo subir a la nube. Si cierras sesión ahora se pierde.'
                : 'Hay $pending cambios que no se pudieron subir a la nube. Si cierras sesión ahora se pierden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar sesión igual'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await syncService.clearLocalDataOnLogout();
    ref.invalidate(databaseProvider);
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  bool _deletingAccount = false;

  /// Borra la cuenta en Supabase y, solo si el servidor lo confirmó, la base
  /// local y la sesión. Lo pendiente de subir se descarta: la cuenta ya no existe.
  Future<void> _deleteAccount() async {
    if (!await showDeleteAccountDialog(context)) return;
    if (!mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount();
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'account.delete');
      if (mounted) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la cuenta. Revisa tu conexión e intenta de nuevo.'),
          ),
        );
      }
      return;
    }
    // La cuenta ya no existe en el servidor: aunque falle la limpieza local,
    // siempre se vuelve al login.
    try {
      await ref.read(syncServiceProvider).clearLocalDataOnLogout();
      ref.invalidate(databaseProvider);
      await ref.read(authServiceProvider).signOut();
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'account.delete_local_cleanup');
    } finally {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hideValues = ref.watch(hideValuesProvider);
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(
          title: Text('Más'),
          primary: false,
          // Barra de navegación de iOS (44pt) + título grande, sin aire de más.
          toolbarHeight: 44,
          expandedHeight: 100,
        ),
        SliverList.list(
          children: [
            InsetGroup(
              children: [
                _NavRow(
                  icon: CupertinoIcons.person_crop_circle,
                  title: 'Tu cuenta',
                  subtitle: ref.watch(accountInfoProvider).displayName,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
                  ),
                ),
              ],
            ),
            InsetGroup(
              children: [
                _NavRow(
                  icon: CupertinoIcons.creditcard,
                  title: 'Tarjetas de crédito',
                  subtitle: 'Corte, cuota de manejo y pagos',
                  onTap: () => _openSection('Tarjetas de crédito', const CreditCardsScreen()),
                ),
                _NavRow(
                  icon: CupertinoIcons.briefcase,
                  title: 'Cuentas de ahorro',
                  subtitle: 'Débito, Nequi y efectivo',
                  onTap: () => _openSection('Cuentas de ahorro', const SavingsScreen()),
                ),
                _NavRow(
                  icon: CupertinoIcons.person_2,
                  title: 'Me deben',
                  subtitle: 'Dinero que prestaste',
                  onTap: () => _openSection('Me deben', const ReceivablesScreen()),
                ),
                _NavRow(
                  icon: CupertinoIcons.repeat,
                  title: 'Auto-pagos',
                  subtitle: 'Egresos que se repiten cada mes',
                  onTap: () => _openSection('Auto-pagos', const AutomaticPaymentsScreen()),
                ),
              ],
            ),
            InsetGroup(
              children: [
                if (advisorEnabled)
                  _NavRow(
                    icon: CupertinoIcons.chat_bubble_2,
                    title: 'Asesor financiero',
                    onTap: () => context.push('/chat'),
                  ),
                _NavRow(
                  icon: CupertinoIcons.square_stack,
                  title: 'Registro con Apple Wallet',
                  onTap: () => context.push('/wallet-shortcut'),
                ),
                _NavRow(
                  icon: CupertinoIcons.book,
                  title: 'Guía de la app',
                  subtitle: 'Vuelve a ver cómo funciona cada sección',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(replay: true)),
                  ),
                ),
              ],
            ),
            InsetGroup(
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(CupertinoIcons.eye_slash),
                  title: const Text('Ocultar valores'),
                  subtitle: const Text('Tapa los montos en todas las pantallas'),
                  activeTrackColor: c.accent,
                  value: hideValues.valueOrNull ?? false,
                  onChanged: hideValues.hasValue
                      ? (_) => ref.read(hideValuesProvider.notifier).toggle()
                      : null,
                ),
                const SyncNowTile(),
              ],
            ),
            InsetGroup(
              children: [
                ListTile(
                  title: Text(
                    'Cerrar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
            InsetGroup(
              children: [
                ListTile(
                  title: Text(
                    _deletingAccount ? 'Eliminando cuenta…' : 'Eliminar cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.danger),
                  ),
                  enabled: !_deletingAccount,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            // Aire final más el área segura de abajo. Dentro del shell la barra
            // inferior ya consume esa área (el cuerpo termina sobre ella), así
            // que esto solo suma cuando la pantalla se muestra sin barra.
            SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ],
    );
  }
}

/// Grupo de filas con esquinas redondeadas y márgenes laterales (lista
/// agrupada inset de iOS).
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: c.surface,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 0.5, indent: 56, color: c.divider),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, required this.onTap, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(CupertinoIcons.chevron_forward, size: 18, color: context.colors.textMuted),
      onTap: onTap,
    );
  }
}

/// «Sincronizar ahora» con el contador de cambios sin subir. Mientras
/// sincroniza solo gira el ícono; el contador queda quieto.
class SyncNowTile extends ConsumerStatefulWidget {
  const SyncNowTile({super.key});

  @override
  ConsumerState<SyncNowTile> createState() => _SyncNowTileState();
}

class _SyncNowTileState extends ConsumerState<SyncNowTile> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    if (ref.read(isSyncingProvider)) _spin.repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    try {
      await ref.read(syncServiceProvider).syncNow();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UserFriendlyErrors.syncFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isSyncingProvider, (_, syncing) {
      if (syncing) {
        _spin.repeat();
      } else {
        _spin
          ..stop()
          ..reset();
      }
    });
    final c = context.colors;
    final isSyncing = ref.watch(isSyncingProvider);
    final pending = ref.watch(pendingChangesCountProvider).valueOrNull ?? 0;
    final status = isSyncing
        ? 'Sincronizando...'
        : switch (pending) {
            0 => 'Todo está en la nube',
            1 => '1 cambio sin subir',
            _ => '$pending cambios sin subir',
          };
    return ListTile(
      leading: RotationTransition(
        turns: _spin,
        child: const Icon(CupertinoIcons.arrow_2_circlepath),
      ),
      title: const Text('Sincronizar ahora'),
      subtitle: Text(status),
      trailing: pending > 0
          ? Badge(
              label: Text('$pending'),
              backgroundColor: c.danger,
              textColor: c.onDanger,
            )
          : null,
      enabled: !isSyncing,
      onTap: _sync,
    );
  }
}
