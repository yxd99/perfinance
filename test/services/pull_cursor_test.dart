import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/services/pull_cursor.dart';

void main() {
  group('pullSince', () {
    test('sin cursor no hay filtro: descarga completa', () {
      expect(pullSince(null), isNull);
    });

    test('retrocede el margen de solapamiento respecto al cursor', () {
      expect(
        pullSince('2026-10-01T12:00:00.000Z'),
        '2026-10-01T11:55:00.000Z',
      );
    });

    test('normaliza a UTC los cursores con offset', () {
      expect(
        pullSince('2026-10-01T07:00:00.000-05:00'),
        '2026-10-01T11:55:00.000Z',
      );
    });
  });

  group('advanceCursor', () {
    test('sin filas conserva el cursor anterior', () {
      expect(advanceCursor('2026-10-01T12:00:00.000Z', const []), '2026-10-01T12:00:00.000Z');
      expect(advanceCursor(null, const []), isNull);
    });

    test('toma el updated_at más reciente de las filas', () {
      final cursor = advanceCursor(null, const [
        {'updated_at': '2026-10-01T10:00:00+00:00'},
        {'updated_at': '2026-10-02T09:30:00.123456+00:00'},
        {'updated_at': '2026-09-30T23:59:59+00:00'},
      ]);

      expect(cursor, '2026-10-02T09:30:00.123456Z');
    });

    test('nunca retrocede: filas más viejas que el cursor no lo mueven', () {
      final cursor = advanceCursor('2026-10-05T00:00:00.000Z', const [
        {'updated_at': '2026-10-01T10:00:00+00:00'},
      ]);

      expect(cursor, '2026-10-05T00:00:00.000Z');
    });

    test('ignora filas sin marca de tiempo y permite otra columna', () {
      final cursor = advanceCursor(
        null,
        const [
          {'deleted_at': null},
          {'deleted_at': '2026-10-03T08:00:00+00:00'},
        ],
        column: 'deleted_at',
      );

      expect(cursor, '2026-10-03T08:00:00.000Z');
    });
  });
}
