# Perfinance

App móvil (Flutter, iOS y Android) de finanzas personales, uso personal del autor y pocos usuarios.

## Qué hace (y qué no)

- Registra **egresos** únicamente. **No se registran ingresos**: no proponer ni agregar esa funcionalidad.
- **Tarjetas de crédito**: alias, día de corte, cuota de manejo, pago mínimo por mes, pagos. Se pueden desactivar (`is_active`) sin borrarlas.
- **Ahorros**: medios de pago (efectivo, débito, otro).
- **Deudas** que el usuario tiene (`debts`): estado `active | paid | hidden`.
- **Me deben** (`receivables`): estado `active | settled | written_off | hidden`. Si el deudor está registrado, se le crea una deuda espejo de solo lectura (`mirrored_debts`).
- **Pagos automáticos**: generan egresos recurrentes; estado `active | paused`.
- **Dashboard** y **chat con asesor financiero** (edge function `financial-advisor`).
- **Apple Wallet**: un atajo de iOS llama a la edge function `log-wallet-expense` al pagar y crea el egreso en Supabase (`[Wallet]: comercio`) sin abrir la app; llega al teléfono por el pull. Se autentica con un token personal (`shortcut_tokens`), no con la sesión. La tarjeta de Wallet se resuelve por asignación guardada (`wallet_cards`, solo en la nube) y, si no hay, por parecido de nombre. Es la única escritura que no pasa por SQLite local.

## Arquitectura: offline-first

Regla central: **toda lectura y escritura de la app va contra SQLite local**. Supabase es la copia en la nube para respaldo y varios dispositivos. La app debe funcionar completa sin conexión.

- `lib/data/database/app_database.dart` — esquema local (`appSchemaVersion`), `createAppSchema` y `upgradeAppSchema`.
- `lib/data/repositories/` — único acceso a SQLite. Cada fila lleva `sync_status`: `synced | pending_insert | pending_update | pending_delete`.
- `lib/services/sync_service.dart` — sincronización con Supabase.
- `lib/features/` — pantallas y providers (Riverpod, `FutureProvider` + repositorio, sin notifiers).
- `supabase/migrations/` — esquema de Postgres, triggers y RLS. `supabase/functions/` — edge functions.

Los saldos (deuda de tarjeta, pagado de una deuda) se calculan en local sobre **todo el historial**. No recortar los datos locales por fecha.

## Cómo funciona la sincronización

- **Push**: sube las filas con `sync_status` pendiente y las marca `synced` solo si Supabase aceptó. Un fallo se reporta a Sentry y la fila queda pendiente. Tras cada escritura local se llama `pushPendingIfOnline()`.
- **Pull incremental**: cada tabla pide solo filas con `updated_at` posterior a su cursor. Los cursores son la hora del servidor, se guardan en la tabla local `sync_cursors` y solo al terminar un pull completo. Sin cursor, la bajada es completa y paginada (Supabase corta en 1000 filas por pedido).
- **Borrados**: se borra de verdad en Supabase; un trigger anota el borrado en `deleted_records` y el pull elimina esas filas en local.
- **Conflictos**: una fila local con cambios pendientes no se pisa en el pull; al subir, gana el último push.
- **Logout** borra el archivo SQLite: antes se sube lo pendiente y se pide confirmación si algo no pudo subirse.

## Reglas al cambiar el esquema

El esquema local y el de Supabase se desfasaron dos veces y causaron pérdida de datos. Para cualquier columna o tabla nueva que se sincronice:

1. Migración de Supabase en `supabase/migrations/NNN_descripcion.sql`, aplicada con `supabase db push`. Nunca SQL a mano desde el dashboard.
2. SQLite: subir `appSchemaVersion`, agregar el cambio en `upgradeAppSchema` **y** en `createAppSchema`.
3. Modelo (`toJson`/`fromJson`), repositorio (`insert`, `update`, `upsertFromRemote`, mapeo de fila) y el mapeo del pull en `sync_service.dart`.
4. `test/data/schema_contract_test.dart` debe pasar: falla si un modelo envía una columna que ninguna migración crea.
5. Tabla nueva que se sube: agregarla a `pushedTables` (`lib/services/pending_changes.dart`) y crearle el trigger `trg_tombstone`.

Las edge functions leen las tablas directo: revisar `supabase/functions/` si se renombra o elimina una columna.

## Errores

Reportar siempre con `ErrorReporter.capture(e, st, operation: 'area.accion', details: {...})` (`lib/core/observability/error_reporter.dart`). No llamar a Sentry directo ni dejar `catch` vacíos.

## Comandos

- Ejecutar: `flutter run --dart-define-from-file=dart_defines.json` (claves en `dart_defines.json.example`; sin `SENTRY_DSN` Sentry queda apagado).
- Tests: `flutter test`. Análisis: `flutter analyze`.
- Migraciones: `supabase migration list --linked`, `supabase db push`.

## Tests

- Base de pruebas: `openTestDatabase()` en `test/helpers/db_helper.dart`, que usa el esquema real de la app. Con `fromVersion` corre la migración real desde un esquema histórico.
- Repositorios se construyen con `Repo(null, dbOverride: db)`.
- `SyncService` no tiene test de integración (depende de Supabase): la lógica nueva de sync va en funciones puras testeables, como `paged_fetch.dart` y `pull_cursor.dart`.

## Idioma

Textos de la interfaz y comentarios en español (voseo). Mensajes de commit en inglés, formato conventional commits.
