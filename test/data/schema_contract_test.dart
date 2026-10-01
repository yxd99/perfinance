import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/automatic_payment.dart';
import 'package:perfinance/data/models/card_payment.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/debt.dart';
import 'package:perfinance/data/models/debt_payment.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/data/models/min_payment_config.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/models/receivable_payment.dart';

/// Columnas por tabla según las migraciones de Supabase versionadas en el repo.
Map<String, Set<String>> parseColumns(String sql) {
  const constraintKeywords = {'PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'};
  final columns = <String, Set<String>>{};

  final create = RegExp(
    r'CREATE TABLE (?:IF NOT EXISTS )?(?:public\.)?(\w+)\s*\((.*?)\n\);',
    caseSensitive: false,
    dotAll: true,
  );
  for (final m in create.allMatches(sql)) {
    final table = columns.putIfAbsent(m.group(1)!, () => {});
    for (final raw in m.group(2)!.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('--')) continue;
      final first = line.split(RegExp(r'\s+')).first;
      if (constraintKeywords.contains(first.toUpperCase())) continue;
      table.add(first);
    }
  }

  final alter = RegExp(
    r'ALTER TABLE (?:IF EXISTS )?(?:public\.)?(\w+)(.*?);',
    caseSensitive: false,
    dotAll: true,
  );
  final addColumn = RegExp(r'ADD COLUMN (?:IF NOT EXISTS )?(\w+)', caseSensitive: false);
  for (final m in alter.allMatches(sql)) {
    final table = columns.putIfAbsent(m.group(1)!, () => {});
    for (final c in addColumn.allMatches(m.group(2)!)) {
      table.add(c.group(1)!);
    }
  }
  return columns;
}

Map<String, Set<String>> _migrationColumns() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return parseColumns(files.map((f) => f.readAsStringSync()).join('\n'));
}

void main() {
  test('parseColumns lee CREATE TABLE y ADD COLUMN', () {
    final columns = parseColumns('''
CREATE TABLE IF NOT EXISTS things (
  id UUID PRIMARY KEY,
  -- comment
  name TEXT NOT NULL,
  UNIQUE (name)
);
ALTER TABLE things
  ADD COLUMN IF NOT EXISTS color TEXT,
  ADD COLUMN size INTEGER;
''');

    expect(columns['things'], {'id', 'name', 'color', 'size'});
  });

  // Lo que el push envía a Supabase: toJson() menos sync_status (solo local).
  final date = DateTime(2026, 1, 1);
  final pushed = <String, Map<String, dynamic>>{
    'credit_cards': CreditCard(
      id: 'x',
      userId: 'u',
      alias: 'a',
      cutOffDay: 1,
      managementFee: 0,
    ).toJson(),
    'payment_methods': PaymentMethod(id: 'x', userId: 'u', name: 'n', type: 'other').toJson(),
    'expenses': Expense(
      id: 'x',
      userId: 'u',
      amount: 1,
      date: date,
      paymentType: 'credit_card',
      paymentRef: 'r',
    ).toJson(),
    'card_payments': CardPayment(id: 'x', cardId: 'c', amount: 1, date: date).toJson(),
    'min_payment_configs': MinPaymentConfig(
      id: 'x',
      cardId: 'c',
      amount: 1,
      year: 2026,
      month: 1,
    ).toJson(),
    'debts': Debt(
      id: 'x',
      userId: 'u',
      name: 'n',
      totalAmount: 1,
      numberOfInstallments: 1,
      dueDate: date,
    ).toJson(),
    'debt_payments': DebtPayment(id: 'x', debtId: 'd', amount: 1, date: date).toJson(),
    'automatic_payments': AutomaticPayment(
      id: 'x',
      userId: 'u',
      paymentType: 'credit_card',
      paymentRef: 'r',
      amount: 1,
      description: 'd',
      nextRunDate: date,
    ).toJson(),
    'receivables': Receivable(id: 'x', userId: 'u', debtorName: 'n', totalAmount: 1).toJson(),
    'receivable_payments': ReceivablePayment(
      id: 'x',
      receivableId: 'r',
      amount: 1,
      date: date,
    ).toJson(),
  };

  group('cada columna que el push envía existe en una migración de Supabase', () {
    final remote = _migrationColumns();
    pushed.forEach((table, json) {
      test(table, () {
        final sent = json.keys.toSet()..remove('sync_status');
        final missing = sent.difference(remote[table] ?? const {});

        expect(
          missing,
          isEmpty,
          reason: 'Falta una migración en supabase/migrations que cree: $table.$missing',
        );
      });
    });
  });
}
