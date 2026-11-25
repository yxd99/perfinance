import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/theme/app_colors.dart';
import 'package:perfinance/features/auth/account_service.dart';
import 'package:perfinance/features/more/email_quota.dart';
import 'package:perfinance/features/more/more_screen.dart' show InsetGroup;

/// Más › Tu cuenta: nombre, correo, correos del mes y cambio de contraseña.
/// Guardar el nombre y cambiar la contraseña necesitan conexión.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late final TextEditingController _name =
      TextEditingController(text: ref.read(accountInfoProvider).name ?? '');
  bool _savingName = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingName = true);
    try {
      await ref.read(accountServiceProvider).updateName(_name.text.trim());
      ref.invalidate(accountInfoProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Nombre guardado.')));
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'account.update_name');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el nombre. Revisa tu conexión e intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(accountInfoProvider);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          InsetGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Cómo quieres que te llamemos',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _savingName ? null : _saveName,
                        child: Text(_savingName ? 'Guardando…' : 'Guardar nombre'),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.at),
                title: const Text('Correo'),
                subtitle: Text(info.email),
              ),
            ],
          ),
          const InsetGroup(children: [EmailQuotaTile()]),
          InsetGroup(
            children: [
              ListTile(
                leading: const Icon(CupertinoIcons.lock),
                title: const Text('Cambiar contraseña'),
                trailing: Icon(CupertinoIcons.chevron_forward, size: 18, color: c.textMuted),
                onTap: _openChangePassword,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pide la contraseña actual, la nueva y su confirmación. Devuelve true al
/// cerrarse si la cambió.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = validateNewPassword(current: _current.text, next: _next.text, confirm: _confirm.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(accountServiceProvider).changePassword(current: _current.text, next: _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on WrongCurrentPasswordException {
      if (mounted) setState(() => _error = 'La contraseña actual no es correcta.');
    } catch (e, st) {
      ErrorReporter.capture(e, st, operation: 'account.change_password');
      if (mounted) {
        setState(() => _error = 'No se pudo cambiar la contraseña. Revisa tu conexión e intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Contraseña')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Contraseña actual'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Contraseña nueva',
              helperText: 'Mínimo 8 caracteres.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Confirma la contraseña nueva'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: c.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Cambiando…' : 'Cambiar contraseña'),
          ),
        ],
      ),
    );
  }
}
