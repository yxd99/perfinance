import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/credit_card.dart';
import 'package:perfinance/data/models/payment_method.dart';
import 'package:perfinance/data/repositories/credit_card_repository.dart';
import 'package:perfinance/data/repositories/payment_method_repository.dart';

import '../../helpers/db_helper.dart';

void main() {
  test('tarjeta: el color se guarda al crear, al editar y al bajar de la nube', () async {
    final db = await openTestDatabase();
    final repo = CreditCardRepository(null, dbOverride: db);
    final card = CreditCard(id: 'c', userId: 'u', alias: 'Visa', cutOffDay: 15, managementFee: 0, colorSlot: 1);
    await repo.insert(card);
    expect((await repo.getById('c'))!.colorSlot, 1);

    await repo.update(card.copyWith(colorSlot: 3));
    final edited = (await repo.getById('c'))!;
    expect(edited.colorSlot, 3);
    expect(edited.syncStatus, 'pending_update');

    await repo.markSynced('c');
    await repo.upsertFromRemote(card.copyWith(colorSlot: 0));
    expect((await repo.getById('c'))!.colorSlot, 0);
    await db.close();
  });

  test('cuenta de ahorro: el color se guarda al crear, al editar y al bajar de la nube', () async {
    final db = await openTestDatabase();
    final repo = PaymentMethodRepository(null, dbOverride: db);
    final pm = PaymentMethod(id: 'p', userId: 'u', name: 'Nequi', colorSlot: 2);
    await repo.insert(pm);
    expect((await repo.getAll('u')).single.colorSlot, 2);

    await repo.update(pm.copyWith(colorSlot: 4));
    expect((await repo.getAll('u')).single.colorSlot, 4);

    await repo.markSynced('p');
    await repo.upsertFromRemote(PaymentMethod(id: 'p', userId: 'u', name: 'Nequi'));
    // La nube sin color deja la cuenta en automático.
    expect((await repo.getAll('u')).single.colorSlot, isNull);
    await db.close();
  });
}
