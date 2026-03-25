# Perfinance

App móvil (iOS y Android) de finanzas personales con modelo **offline-first** y sincronización con **Supabase**.

## Requisitos

- Flutter 3.x
- Cuenta en [Supabase](https://supabase.com)

## Configuración

1. **Crear proyecto en Supabase** y obtener URL y anon key en Settings > API.

2. **Ejecutar el esquema SQL** en el SQL Editor del dashboard de Supabase:
   - Contenido de `supabase/schema.sql` (tablas, triggers, RLS).

3. **Auth sin correo de verificación (recomendado para esta app):**
   - En el dashboard de Supabase: **Authentication → Providers → Email**.
   - Desactiva **"Confirm email"**.
   - Así, al registrarse el usuario queda autenticado de inmediato y no se envía correo de validación; la app lo llevará directo al inicio.

4. **Configurar la app** con tu proyecto Supabase (sin guardar secretos en el código):
   - Copia `dart_defines.json.example` a `dart_defines.json` y rellena URL y anon key (Settings → API en Supabase). `dart_defines.json` está en `.gitignore`.
   - Ejecuta o compila con:
     ```bash
     flutter run --dart-define-from-file=dart_defines.json
     ```
   - Alternativa puntual:
     ```bash
     flutter run --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co --dart-define=SUPABASE_ANON_KEY=tu-anon-key
     ```

## Ejecutar

```bash
flutter pub get
flutter run
```

Para iOS: `flutter run -d ios`  
Para Android: `flutter run -d android`

## Funcionalidad

- **Auth:** registro e inicio de sesión con correo y contraseña (Supabase Auth).
- **Tarjetas de crédito:** alias, día de corte, cuota de manejo; pago mínimo por mes; registrar pagos.
- **Ahorros:** medios de pago (efectivo, débito, otro).
- **Egresos:** registrar gastos eligiendo tarjeta de crédito o medio de ahorro.
- **Dashboard:** deuda total, uso por tarjeta, comparativa mes actual vs anterior (verde/rojo con %).
- **Offline:** toda la lectura/escritura va a SQLite local; al recuperar conexión se sincroniza con Supabase (push de pendientes y pull).

## Estructura

- `lib/core/` — configuración y router.
- `lib/data/` — modelos, SQLite y repositorios (con `sync_status`).
- `lib/features/` — auth, tarjetas, ahorros, egresos, dashboard.
- `lib/services/` — SyncService, MinPaymentService, DashboardService, conectividad.
- `supabase/schema.sql` — esquema y RLS para ejecutar en Supabase.
