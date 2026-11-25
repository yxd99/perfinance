# Cómo contribuir

¡Gracias por tu interés! Perfinance es una app personal publicada como código abierto;
las contribuciones son bienvenidas dentro del alcance del proyecto.

## Antes de empezar

- Lee [`CLAUDE.md`](CLAUDE.md): describe la arquitectura offline-first y las reglas del esquema.
- La app registra **solo egresos**. No se aceptan cambios que agreguen ingresos.
- Para cambios grandes, abre primero un issue y acuerda el enfoque.

## Flujo

1. Haz fork y crea una rama desde `main` (`feat/...`, `fix/...`).
2. Configura tu propio proyecto de Supabase (ver [README](README.md)); nunca uses credenciales ajenas.
3. Escribe tests para el comportamiento nuevo y ejecuta:
   ```bash
   flutter analyze
   flutter test
   ```
4. Commits en inglés con [Conventional Commits](https://www.conventionalcommits.org/)
   (`feat: ...`, `fix: ...`) y **firmados** (`git commit -S`); `main` rechaza commits sin firma.
5. Abre el pull request contra `main` y completa la plantilla. Necesita la aprobación del
   mantenedor y todos los checks en verde.

## Cambios de esquema

Toda columna o tabla sincronizada necesita, en el mismo PR:

1. Migración nueva `supabase/migrations/NNN_descripcion.sql`.
2. `appSchemaVersion` subido, con el cambio en `upgradeAppSchema` **y** `createAppSchema`.
3. Modelo, repositorio y mapeo del pull en `sync_service.dart` actualizados.
4. `test/data/schema_contract_test.dart` en verde.
5. Tabla nueva: política RLS, trigger `trg_tombstone` y entrada en `pushedTables`.

## Estilo

- Textos de la interfaz en español neutro, tratando al usuario de tú.
- Errores siempre con `ErrorReporter.capture(...)`; nada de `catch` vacíos.

## Seguridad

Las vulnerabilidades se reportan en privado: ver [SECURITY.md](SECURITY.md).

Al participar aceptas el [Código de conducta](CODE_OF_CONDUCT.md).
