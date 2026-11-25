import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Correos enviados este mes y tope mensual de la cuenta (migración 020).
/// Vive solo en la nube, así que se consulta en línea y no pasa por SQLite.
class EmailQuota {
  const EmailQuota({required this.sent, required this.quota});

  /// Lee la respuesta de la RPC `my_email_quota` (una fila, sola o en lista).
  factory EmailQuota.fromRpc(Object? data) {
    final row = data is List ? data.first : data;
    final map = Map<String, dynamic>.from(row as Map);
    return EmailQuota(
      sent: (map['sent_count'] as num).toInt(),
      quota: (map['quota'] as num).toInt(),
    );
  }

  final int sent;
  final int quota;

  int get remaining => sent >= quota ? 0 : quota - sent;
}

const _monthsEs = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Texto de la fila, por ejemplo "Te quedan 7 de 10 · se reinician el 1 de diciembre".
String emailQuotaLabel(EmailQuota quota, DateTime now) {
  final reset = 'se reinician el 1 de ${_monthsEs[now.month % 12]}';
  final left = quota.remaining;
  if (left == 0) return 'No te quedan correos este mes · $reset';
  final verb = left == 1 ? 'Te queda' : 'Te quedan';
  return '$verb $left de ${quota.quota} · $reset';
}

final emailQuotaProvider = FutureProvider.autoDispose<EmailQuota>((ref) async {
  final data = await Supabase.instance.client.rpc('my_email_quota').timeout(const Duration(seconds: 10));
  return EmailQuota.fromRpc(data);
});

/// Fila "Correos de este mes". Sin conexión no muestra error, solo lo dice.
class EmailQuotaTile extends ConsumerWidget {
  const EmailQuotaTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(emailQuotaProvider);
    final subtitle = quota.when(
      data: (q) => emailQuotaLabel(q, DateTime.now()),
      loading: () => 'Consultando…',
      error: (_, __) => 'Disponible con conexión a internet.',
    );
    return ListTile(
      leading: const Icon(CupertinoIcons.envelope),
      title: const Text('Correos de este mes'),
      subtitle: Text(subtitle),
    );
  }
}
