import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/services/paged_fetch.dart';

/// Simula una API que nunca devuelve más de [cap] filas por pedido.
Future<List<dynamic>> Function(int, int) _cappedSource(int total, {required int cap}) {
  final rows = List.generate(total, (i) => {'id': i});
  return (from, to) async {
    if (from >= rows.length) return [];
    final end = (to + 1).clamp(0, rows.length);
    return rows.sublist(from, end).take(cap).toList();
  };
}

void main() {
  test('devuelve todo cuando entra en una sola página', () async {
    final rows = await fetchAllPages(_cappedSource(3, cap: 10), pageSize: 10);

    expect(rows.map((r) => r['id']), [0, 1, 2]);
  });

  test('sigue pidiendo páginas hasta agotar las filas', () async {
    final rows = await fetchAllPages(_cappedSource(25, cap: 10), pageSize: 10);

    expect(rows, hasLength(25));
    expect(rows.last['id'], 24);
  });

  test('no pierde filas cuando el total es múltiplo exacto de la página', () async {
    final rows = await fetchAllPages(_cappedSource(20, cap: 10), pageSize: 10);

    expect(rows, hasLength(20));
  });

  test('devuelve lista vacía cuando no hay filas', () async {
    final rows = await fetchAllPages(_cappedSource(0, cap: 10), pageSize: 10);

    expect(rows, isEmpty);
  });
}
