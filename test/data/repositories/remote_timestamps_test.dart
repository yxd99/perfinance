import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/database/app_database.dart';
import 'package:perfinance/data/models/receivable.dart';
import 'package:perfinance/data/repositories/receivable_repository.dart';

import '../../helpers/db_helper.dart';

Receivable _remote(String id, String createdAt) => Receivable(
      id: id,
      userId: 'user-1',
      debtorName: 'Deudor $id',
      totalAmount: 100,
      syncStatus: 'synced',
      createdAt: createdAt,
      updatedAt: '2026-06-01T00:00:00+00:00',
    );

void main() {
  late dynamic db;
  late ReceivableRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    repo = ReceivableRepository(null, dbOverride: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertFromRemote conserva created_at y updated_at de la nube', () async {
    await repo.upsertFromRemote(_remote('r-1', '2026-01-15T10:00:00+00:00'));

    final rows = await db.query(tableReceivables) as List;
    expect(rows.first['created_at'], '2026-01-15T10:00:00+00:00');
    expect(rows.first[columnUpdatedAt], '2026-06-01T00:00:00+00:00');
  });

  test('la lista queda ordenada por creación real, no por orden de bajada', () async {
    await repo.upsertFromRemote(_remote('nuevo', '2026-03-01T00:00:00+00:00'));
    await repo.upsertFromRemote(_remote('viejo', '2026-01-01T00:00:00+00:00'));

    final all = await repo.getAll('user-1');
    expect(all.map((r) => r.id), ['nuevo', 'viejo']);
  });
}
