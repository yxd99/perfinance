# Política de seguridad

## Versiones soportadas

Solo la última versión publicada (rama `main`) recibe correcciones de seguridad.

## Cómo reportar una vulnerabilidad

**No abras un issue público.** Usa el reporte privado de GitHub:
[Security → Report a vulnerability](https://github.com/yxd99/perfinance/security/advisories/new).

Incluye, si puedes:

- Qué componente afecta (app, Edge Function, migración/RLS, workflow).
- Pasos para reproducirlo y el impacto que esperas.
- Una propuesta de corrección, si la tienes.

Recibirás respuesta en un plazo de 7 días. Una vez corregido, se publica un aviso
de seguridad y se da crédito a quien lo reportó, si lo desea.

## Alcance

Dentro del alcance:

- Acceso a datos de otro usuario (políticas RLS de Supabase, Edge Functions).
- Fuga de credenciales o tokens (`shortcut_tokens`, claves de API).
- Ejecución de código o escalamiento de privilegios en los workflows de GitHub Actions.

Fuera del alcance:

- La `anon key` de Supabase y la URL del proyecto: son públicas por diseño y viajan
  dentro de la app; la protección real está en RLS.
- Ataques que requieren un dispositivo desbloqueado o con root/jailbreak.
- Denegación de servicio por volumen.

## Prácticas del repositorio

- `main` está protegida: solo entra código por pull request revisado, con checks en verde
  y commits firmados.
- Escaneo de secretos (GitHub y gitleaks), CodeQL y revisión de dependencias en cada PR.
- Las acciones de GitHub están fijadas por SHA y Dependabot las mantiene al día.
- Los secretos de publicación viven en el environment `production`, que solo acepta `main`.
- Nunca subas `dart_defines.json`, keystores (`*.jks`), `key.properties` ni archivos `.env`.
