import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/data/models/expense.dart';
import 'package:perfinance/features/dashboard/month_pace.dart';

Expense _e(String id, double amount, DateTime date, {String type = 'credit_card', String ref = 'card-1'}) =>
    Expense(id: id, userId: 'u', amount: amount, date: date, paymentType: type, paymentRef: ref);

void main() {
  group('computeMonthSpend', () {
    final today = DateTime(2026, 11, 17, 15, 30);

    test('suma todo el mes seleccionado y agrupa por cuenta, mayor primero', () {
      final s = computeMonthSpend([
        _e('1', 100, DateTime(2026, 11, 2)),
        _e('2', 50, DateTime(2026, 11, 16), type: 'payment_method', ref: 'cash'),
        _e('3', 300, DateTime(2026, 11, 17, 9), type: 'payment_method', ref: 'cash'),
        _e('4', 999, DateTime(2026, 12, 1)),
        _e('5', 70, DateTime(2026, 10, 5)),
      ], DateTime(2026, 11, 1), today);

      expect(s.total, 450);
      expect(s.count, 3);
      expect(s.byAccount.map((a) => a.paymentRef), ['cash', 'card-1']);
      expect(s.byAccount.first.total, 350);
      expect(s.byAccount.first.count, 2);
      expect(s.byAccount.first.paymentType, 'payment_method');
      expect(s.lastMonthTotal, 70);
    });

    test('no cuenta egresos con fecha posterior a ahora, igual que Egresos «Mes»', () {
      final s = computeMonthSpend([
        _e('1', 100, DateTime(2026, 11, 17, 9)),
        _e('2', 18500, DateTime(2026, 11, 17, 19, 25)),
        _e('3', 40, DateTime(2026, 11, 25)),
      ], DateTime(2026, 11, 1), today);

      expect(s.total, 100);
      expect(s.count, 1);
      expect(s.byAccount.single.total, 100);
    });

    test('mes en curso: compara hasta el mismo día del mes anterior', () {
      final s = computeMonthSpend([
        _e('1', 120, DateTime(2026, 11, 10)),
        _e('2', 100, DateTime(2026, 10, 17, 23)),
        _e('3', 400, DateTime(2026, 10, 18)),
      ], DateTime(2026, 11, 1), today);

      expect(s.isInProgress, isTrue);
      expect(s.dayOfMonth, 17);
      expect(s.daysInMonth, 30);
      expect(s.toSameDay, 120);
      expect(s.lastMonthToSameDay, 100);
      expect(s.lastMonthTotal, 500);
    });

    test('mes cerrado: el día es el total de días del mes', () {
      final s = computeMonthSpend([], DateTime(2026, 9, 1), today);
      expect(s.isInProgress, isFalse);
      expect(s.dayOfMonth, 30);
      expect(s.daysInMonth, 30);
    });

    test('enero compara contra diciembre del año anterior y recorta el día', () {
      final s = computeMonthSpend([
        _e('1', 80, DateTime(2025, 12, 31)),
      ], DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(s.lastMonthTotal, 80);
      expect(s.lastMonthToSameDay, 80);
    });

    test('marzo 31 compara contra todo febrero', () {
      final s = computeMonthSpend([
        _e('1', 40, DateTime(2026, 2, 28)),
      ], DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(s.lastMonthToSameDay, 40);
    });
  });

  group('ringFraction', () {
    MonthSpend spend(double total, double last) => MonthSpend(
          total: total,
          count: 0,
          toSameDay: total,
          lastMonthTotal: last,
          lastMonthToSameDay: last,
          dayOfMonth: 17,
          daysInMonth: 30,
          isInProgress: true,
          month: DateTime(2026, 11),
          byAccount: const [],
        );

    test('es lo gastado sobre el total del mes anterior', () {
      expect(ringFraction(spend(62, 100)), closeAs(0.62));
    });
    test('se queda en 1 cuando se pasa del mes anterior', () {
      expect(ringFraction(spend(150, 100)), 1);
    });
    test('es 0 sin mes anterior', () {
      expect(ringFraction(spend(150, 0)), 0);
    });
  });

  group('paceSentence', () {
    MonthSpend spend({
      required double toSameDay,
      required double lastToSameDay,
      double total = 0,
      double lastTotal = 0,
      bool inProgress = true,
    }) =>
        MonthSpend(
          total: total,
          count: 0,
          toSameDay: toSameDay,
          lastMonthTotal: lastTotal,
          lastMonthToSameDay: lastToSameDay,
          dayOfMonth: 17,
          daysInMonth: 30,
          isInProgress: inProgress,
          month: DateTime(2026, 11),
          byAccount: const [],
        );

    test('más que a esta altura del mes anterior', () {
      expect(paceSentence(spend(toSameDay: 112, lastToSameDay: 100, lastTotal: 300)),
          '12% más que a esta altura de octubre');
    });
    test('menos que a esta altura del mes anterior', () {
      expect(paceSentence(spend(toSameDay: 75, lastToSameDay: 100, lastTotal: 300)),
          '25% menos que a esta altura de octubre');
    });
    test('igual cuando la diferencia redondea a 0', () {
      expect(paceSentence(spend(toSameDay: 100.2, lastToSameDay: 100, lastTotal: 300)),
          'Igual que a esta altura de octubre');
    });
    test('sin base al mismo día, usa el total del mes anterior', () {
      expect(paceSentence(spend(toSameDay: 60, lastToSameDay: 0, total: 62, lastTotal: 100)),
          '62% de lo que gastaste en octubre');
    });
    test('sin mes anterior', () {
      expect(paceSentence(spend(toSameDay: 60, lastToSameDay: 0, total: 60)),
          'Sin egresos en octubre para comparar');
    });
    test('mes cerrado compara totales', () {
      expect(paceSentence(spend(toSameDay: 0, lastToSameDay: 0, total: 90, lastTotal: 100, inProgress: false)),
          '10% menos que en octubre');
    });
  });

  group('cutOffStatus', () {
    test('hoy, mañana y en N días', () {
      expect(cutOffStatus(17, DateTime(2026, 11, 17)), 'Corte hoy');
      expect(cutOffStatus(18, DateTime(2026, 11, 17)), 'Corte mañana');
      expect(cutOffStatus(20, DateTime(2026, 11, 17)), 'Corte en 3 días');
    });
    test('el corte que ya pasó cuenta desde el mes siguiente', () {
      expect(cutOffStatus(2, DateTime(2026, 11, 28)), 'Corte en 4 días');
    });
    test('día 31 se recorta al último día del mes', () {
      expect(cutOffStatus(31, DateTime(2026, 11, 28)), 'Corte en 2 días');
    });
    test('null si falta más de una semana', () {
      expect(cutOffStatus(30, DateTime(2026, 11, 1)), isNull);
    });
  });

  test('monthNameEs', () {
    expect(monthNameEs(1), 'Enero');
    expect(monthNameEs(11), 'Noviembre');
  });

  group('ringLabel', () {
    MonthSpend spend({
      required double total,
      required double lastMonthTotal,
      int day = 18,
      int days = 30,
      bool inProgress = true,
    }) =>
        MonthSpend(
          month: DateTime(2026, 11, 1),
          total: total,
          count: 1,
          toSameDay: total,
          lastMonthTotal: lastMonthTotal,
          lastMonthToSameDay: lastMonthTotal / 2,
          dayOfMonth: day,
          daysInMonth: days,
          isInProgress: inProgress,
          byAccount: const [],
        );

    test('con mes anterior: el centro dice el porcentaje del relleno y de qué mes', () {
      final l = ringLabel(spend(total: 850, lastMonthTotal: 1000));
      expect(l.value, '85%');
      expect(l.caption, 'de octubre');
      expect(l.spoken, '85% de lo gastado en octubre');
    });

    test('pasado el mes anterior: el número sigue subiendo aunque el anillo ya esté lleno', () {
      final s = spend(total: 1200, lastMonthTotal: 1000);
      expect(ringLabel(s).value, '120%');
      expect(ringFraction(s), 1);
    });

    test('sin mes anterior: el centro sigue mostrando los días', () {
      final l = ringLabel(spend(total: 850, lastMonthTotal: 0));
      expect(l.value, '18');
      expect(l.caption, 'de 30 días');
      expect(l.spoken, 'Día 18 de 30');
    });

    test('la cuenta de días pasa a una línea aparte solo si el centro muestra el porcentaje y el mes sigue', () {
      expect(ringDayLine(spend(total: 850, lastMonthTotal: 1000)), 'Día 18 de 30');
      expect(ringDayLine(spend(total: 850, lastMonthTotal: 0)), isNull);
      expect(ringDayLine(spend(total: 850, lastMonthTotal: 1000, day: 30, inProgress: false)), isNull);
    });

    test('enero compara contra diciembre', () {
      final s = MonthSpend(
        month: DateTime(2027, 1, 1),
        total: 50,
        count: 1,
        toSameDay: 50,
        lastMonthTotal: 200,
        lastMonthToSameDay: 100,
        dayOfMonth: 10,
        daysInMonth: 31,
        isInProgress: true,
        byAccount: const [],
      );
      expect(ringLabel(s).caption, 'de diciembre');
      expect(ringLabel(s).value, '25%');
    });
  });
}

Matcher closeAs(double v) => closeTo(v, 1e-9);
