# Perfinance

[![Android release](https://github.com/yxd99/perfinance/actions/workflows/android-release.yml/badge.svg)](https://github.com/yxd99/perfinance/actions/workflows/android-release.yml)
[![Security](https://github.com/yxd99/perfinance/actions/workflows/security.yml/badge.svg)](https://github.com/yxd99/perfinance/actions/workflows/security.yml)

App móvil (iOS y Android) de finanzas personales, **offline-first**, hecha con Flutter y
sincronizada con [Supabase](https://supabase.com). Registra tus egresos, tarjetas de crédito,
deudas y lo que te deben, y funciona completa sin conexión.

## Funcionalidad

- **Egresos:** registra gastos con tarjeta de crédito o medio de pago. La app registra solo egresos.
- **Tarjetas de crédito:** alias, día de corte, cuota de manejo, pago mínimo por mes y pagos. Se pueden desactivar sin borrarlas.
- **Ahorros:** medios de pago (efectivo, débito, otro).
- **Deudas** y **me deben:** con abonos; si quien te debe usa la app, ve la deuda en su cuenta.
- **Pagos automáticos:** egresos recurrentes que puedes pausar.
- **Dashboard:** deuda total, uso por tarjeta y comparativa contra el mes anterior.
- **Apple Wallet:** un atajo de iOS registra el egreso al pagar, sin abrir la app.

## Arquitectura

Toda lectura y escritura va contra **SQLite local**; Supabase es la copia en la nube para
respaldo y varios dispositivos. Cada fila lleva `sync_status` y un servicio de sincronización
sube lo pendiente y baja cambios de forma incremental. Detalle completo en [`CLAUDE.md`](CLAUDE.md).

| Carpeta | Contenido |
| --- | --- |
| `lib/core/` | Configuración, router, observabilidad |
| `lib/data/` | Modelos, esquema SQLite y repositorios |
| `lib/features/` | Pantallas y providers (Riverpod) |
| `lib/services/` | Sincronización, conectividad, cálculos |
| `supabase/migrations/` | Esquema de Postgres, triggers y RLS |
| `supabase/functions/` | Edge Functions (Deno) |

## Puesta en marcha

Requisitos: Flutter 3.47+, [Supabase CLI](https://supabase.com/docs/guides/cli) y un proyecto propio de Supabase.

1. **Aplica las migraciones** en tu proyecto:
   ```bash
   supabase link --project-ref <tu-project-ref>
   supabase db push
   ```
   Todo cambio de esquema va como archivo nuevo `NNN_descripcion.sql` y se aplica con
   `supabase db push`, nunca a mano desde el dashboard.

2. **Auth:** en *Authentication → Providers → Email* puedes desactivar *Confirm email* para
   que el registro inicie sesión de inmediato.

3. **Configura la app** sin guardar secretos en el código:
   ```bash
   cp dart_defines.json.example dart_defines.json   # rellena URL y anon key
   flutter pub get
   flutter run --dart-define-from-file=dart_defines.json
   ```
   `dart_defines.json` está en `.gitignore`. Sin `SENTRY_DSN`, Sentry queda apagado.

4. **Edge Functions** (opcional): `supabase functions deploy <nombre>`. Los secretos
   (`RESEND_API_KEY`, etc.) se configuran con `supabase secrets set`, nunca en el repositorio.

## Tests

```bash
flutter analyze
flutter test
```

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md). Los PR van contra `main`, necesitan revisión, checks en
verde y commits firmados.

## Seguridad

¿Encontraste una vulnerabilidad? **No abras un issue público**: repórtala en privado según
[SECURITY.md](SECURITY.md).

## Licencia

Distribuido bajo la licencia [MIT](LICENSE).
