import 'package:flutter_test/flutter_test.dart';
import 'package:perfinance/features/more/email_quota.dart';

void main() {
  group('EmailQuota.fromRpc', () {
    test('lee la fila que devuelve my_email_quota', () {
      final quota = EmailQuota.fromRpc([
        {'sent_count': 3, 'quota': 10},
      ]);
      expect(quota.sent, 3);
      expect(quota.quota, 10);
      expect(quota.remaining, 7);
    });

    test('acepta la fila sola (sin lista)', () {
      final quota = EmailQuota.fromRpc({'sent_count': 0, 'quota': 25});
      expect(quota.remaining, 25);
    });

    test('nunca muestra cupos negativos si bajaste el tope a mitad de mes', () {
      expect(const EmailQuota(sent: 12, quota: 10).remaining, 0);
    });
  });

  group('emailQuotaLabel', () {
    test('dice cuántos quedan y cuándo se reinician', () {
      expect(
        emailQuotaLabel(const EmailQuota(sent: 3, quota: 10), DateTime(2026, 11, 24)),
        'Te quedan 7 de 10 · se reinician el 1 de diciembre',
      );
    });

    test('sin cupos lo dice claro', () {
      expect(
        emailQuotaLabel(const EmailQuota(sent: 10, quota: 10), DateTime(2026, 12, 5)),
        'No te quedan correos este mes · se reinician el 1 de enero',
      );
    });

    test('singular cuando queda uno', () {
      expect(
        emailQuotaLabel(const EmailQuota(sent: 9, quota: 10), DateTime(2026, 11, 24)),
        'Te queda 1 de 10 · se reinician el 1 de diciembre',
      );
    });
  });
}
