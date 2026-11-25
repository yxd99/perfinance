# Release de Android (CI → GitHub Releases)

`.github/workflows/android-release.yml`:

- **Pull requests**: `flutter analyze --no-fatal-infos` + `flutter test`.
- **Push a `main`** (o "Run workflow" manual): además compila el APK firmado y
  publica un release en GitHub con tres archivos: `perfinance.apk`,
  `perfinance.apk.sha256` y `version.json`. El job corre en el environment
  `production`, que solo acepta `main`.

La versión visible sale de `version:` en `pubspec.yaml` (la parte antes del `+`).
El build number es `github.run_number`: cada deploy es mayor que el anterior.
El tag es `v<versión>-<build>`, por ejemplo `v1.0.0-42`.

El release se crea como borrador y se publica cuando todos los archivos están
arriba, así `releases/latest` nunca queda sin `version.json`.

## Verificar un APK

Cada APK lleva una atestación de procedencia firmada (SLSA build provenance):
prueba que salió de este repositorio y de qué commit. Para verificarlo:

```bash
gh attestation verify perfinance.apk --repo yxd99/perfinance
```

También puedes comparar el hash con `perfinance.apk.sha256` del mismo release.

## Aviso de actualización en la app

Al abrir, la app (solo Android) descarga
`https://github.com/<repo>/releases/latest/download/version.json` y, si su
`build` es mayor que el del APK instalado (`APP_BUILD`), muestra un banner con
"Descargar". Esa URL no pasa por la API de GitHub, así que no tiene límite de
pedidos. Los builds locales no tienen `APP_BUILD` y no muestran el aviso.

El aviso solo se activa si el build lleva `DISTRIBUTION=github` y
`UPDATE_REPOSITORY=<dueño>/<nombre>`; el CI los define con su propio
repositorio, así un fork avisa de sus propios releases. El build de Google Play
no debe definirlos: Play prohíbe que una app instalada desde la tienda se
actualice por fuera de ella.

## Transición desde Google Drive

Las versiones anteriores leían un `version.json` en Google Drive. Mientras
queden instalaciones de esas versiones, el CI también sube el APK y un
manifiesto a Drive (paso "Upload to Google Drive"). Ese APK ya lee GitHub
Releases, así que quien actualice desde Drive pasa al canal nuevo.

Cuando todas las instalaciones estén en una versión que lee GitHub, borra ese
paso, `scripts/drive_upload.sh` y los secrets `GDRIVE_*`.

## Setup (una sola vez)

### 1. Clave de firma

Android solo instala una actualización firmada con la misma clave. Genera una y
guárdala fuera del repo, con sus claves en un gestor de contraseñas (si se
pierde, todos tienen que desinstalar):

```bash
keytool -genkeypair -v -keystore perfinance-release.jks -alias perfinance \
  -keyalg RSA -keysize 2048 -validity 10000
chmod 600 perfinance-release.jks
base64 -i perfinance-release.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

El keystore es PKCS12: la clave de la llave es la misma del keystore.

### 2. Secrets de GitHub (Settings → Secrets and variables → Actions)

Carga cada uno por separado con `gh secret set <NOMBRE>`; no pegues varios
comandos juntos, porque el prompt puede tomar la línea siguiente como valor.

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | El `.jks` en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Clave del keystore |
| `ANDROID_KEY_ALIAS` | `perfinance` |
| `ANDROID_KEY_PASSWORD` | Clave de la llave (la misma del keystore) |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN` | Igual que `dart_defines.json` |
| `GDRIVE_*` | Solo durante la transición; ver abajo |

### 3. Google Drive (solo durante la transición)

| Secret | Valor |
|---|---|
| `GDRIVE_CLIENT_ID` | Client ID OAuth |
| `GDRIVE_CLIENT_SECRET` | Client secret OAuth |
| `GDRIVE_REFRESH_TOKEN` | Refresh token |
| `GDRIVE_APK_FILE_ID` | ID de `perfinance.apk` en Drive |
| `GDRIVE_MANIFEST_FILE_ID` | ID de `version.json` en Drive |

Para regenerar el refresh token: en https://developers.google.com/oauthplayground,
engranaje → "Use your own OAuth credentials" → scope
`https://www.googleapis.com/auth/drive` → "Authorize APIs" → "Exchange
authorization code for tokens". La app OAuth debe estar publicada ("In
production"); en modo "Testing" el token vence a los 7 días.
