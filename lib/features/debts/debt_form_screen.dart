import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfinance/core/observability/error_reporter.dart';
import 'package:perfinance/core/utils/date_format_utils.dart';
import 'package:perfinance/services/sync_service.dart';
import 'package:perfinance/core/widgets/currency_input.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/repositories/debt_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/debts/debts_provider.dart';
import 'package:uuid/uuid.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  final Debt? editDebt;

  const DebtFormScreen({super.key, this.editDebt});

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();
  final _installmentsController = TextEditingController();
  DateTime _dueDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.editDebt != null) {
      final d = widget.editDebt!;
      _nameController.text = d.name;
      _totalController.text = formatCurrency(d.totalAmount);
      _installmentsController.text = d.numberOfInstallments.toString();
      _dueDate = d.dueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editDebt != null ? 'Editar deuda' : 'Nueva deuda')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre o descripción',
                hintText: 'Ej: TV, muebles, préstamo...',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 16),
            CurrencyTextField(
              controller: _totalController,
              decoration: const InputDecoration(labelText: 'Valor total a pagar'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _installmentsController,
              decoration: const InputDecoration(
                labelText: 'Cantidad de cuotas',
                hintText: 'Ej: 12',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad de cuotas';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Debe ser al menos 1';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha máximo de pago'),
              subtitle: Text(formatDisplayDate(_dueDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    final total = parseCurrency(_totalController.text);
    if (total == null || total <= 0) return;
    final installments = int.tryParse(_installmentsController.text.trim());
    if (installments == null || installments < 1) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(debtRepositoryProvider);
    if (widget.editDebt != null) {
      final d = widget.editDebt!;
      await repo.update(Debt(
        id: d.id,
        userId: d.userId,
        name: name,
        totalAmount: total,
        numberOfInstallments: installments,
        dueDate: _dueDate,
        syncStatus: d.syncStatus,
        updatedAt: d.updatedAt,
        createdAt: d.createdAt,
      ));
    } else {
      await repo.insert(Debt(
        id: const Uuid().v4(),
        userId: user.id,
        name: name,
        totalAmount: total,
        numberOfInstallments: installments,
        dueDate: _dueDate,
      ));
    }
    if (mounted) {
      ref.invalidate(debtsListProvider);
      ref
          .read(syncServiceProvider)
          .pushPendingIfOnline()
          .catchError((Object e, StackTrace st) => ErrorReporter.capture(e, st, operation: 'debts.push'));
      Navigator.pop(context);
    }
  }
}
