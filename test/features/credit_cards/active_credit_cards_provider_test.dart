import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/features/auth/auth_provider.dart';
import 'package:perfinance/features/credit_cards/credit_cards_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/db_helper.dart';

void main() {
  sqfliteFfiInit();

  const userId = 'user-1';
  late dynamic db;
  late CreditCardRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = await openTestDatabase();
    repo = CreditCardRepository(null, dbOverride: db);
    container = ProviderContainer(
      overrides: [
        creditCardRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(_FakeUser(userId))),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('activeCreditCardsListProvider retorna solo tarjetas con isActive=true', () async {
    await repo.insert(CreditCard(
      id: 'c1',
      userId: userId,
      alias: 'Activa',
      cutOffDay: 10,
      managementFee: 0,
      isActive: true,
    ));
    await repo.insert(CreditCard(
      id: 'c2',
      userId: userId,
      alias: 'Inactiva',
      cutOffDay: 10,
      managementFee: 0,
      isActive: false,
    ));

    final result = await container.read(activeCreditCardsListProvider.future);
    expect(result.map((c) => c.id), ['c1']);
  });
}

class _FakeUser implements User {
  _FakeUser(this.id);

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
