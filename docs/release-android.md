# Release de Android (CI → Google Drive)

`.github/workflows/android-release.yml`:

- **Pull requests**: `flutter analyze --no-fatal-infos` + `flutter test`.
- **Push a `main`** (o "Run workflow" manual): además compila el APK firmado y
  **reemplaza el contenido** de dos archivos que ya existen en Drive:
  `perfinance.apk` y `version.json`. Se conservan su ID, su link y sus permisos;
  la carpeta nunca se toca ni se comparte.

La versión visible sale de `version:` en `pubspec.yaml` (la parte antes del `+`).
El build number es `github.run_number`: cada deploy es mayor que el anterior.

## Aviso de actualización en la app

Al abrir, la app (solo Android) descarga `version.json` y, si su `build` es mayor
que el del APK instalado (`APP_BUILD`), muestra un banner con "Descargar".
Los builds locales no tienen `APP_BUILD` y no muestran el aviso.

El aviso solo se activa si el build lleva `DISTRIBUTION=drive`, que define el
job de Drive del CI. El build de Google Play no debe definirlo: Play prohíbe que
una app instalada desde la tienda se actualice por fuera de ella, y sin ese
valor el aviso queda apagado aunque `UPDATE_MANIFEST_ID` esté presente.

## Setup (una sola vez)

### 1. Clave de firma

Android solo instala una actualización firmada con la misma clave. Generá una y
guardala fuera del repo (si se pierde, todos tienen que desinstalar):

```bash
keytool -genkeypair -v -keystore perfinance-release.jks -alias perfinance \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -i perfinance-release.jks | pbcopy   # valor de ANDROID_KEYSTORE_BASE64
```

Los APK subidos a mano estaban firmados con la clave debug: **hay que
desinstalar la app una vez** e instalar el primer APK del CI.

### 2. Archivos en Drive

1. `perfinance.apk`: el archivo que ya está en la carpeta. Compartir → "Cualquier
   persona con el enlace" → Lector. Copiar su ID (`/file/d/<ID>/view`).
2. `version.json`: subir un archivo con `{}` a la misma carpeta, compartirlo
   igual y copiar su ID.

### 3. OAuth de Google Drive

Una service account no tiene espacio en un Drive personal; se usa tu cuenta:

1. Google Cloud Console → habilitar **Google Drive API**.
2. Pantalla de consentimiento OAuth → tipo "Externo" → **publicar la app**
   ("In production"). En modo "Testing" el refresh token vence a los 7 días.
3. Clientes → ID de cliente OAuth tipo "Aplicación web", con URI de redirección
   autorizado `https://developers.google.com/oauthplayground`.
4. En https://developers.google.com/oauthplayground: engranaje → "Use your own
   OAuth credentials" (client ID/secret del paso 3) → scope
   `https://www.googleapis.com/auth/drive` → "Authorize APIs" → "Exchange
   authorization code for tokens" → copiar el `refresh_token`.

### 4. Secrets de GitHub (Settings → Secrets and variables → Actions)

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | El `.jks` en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Clave del keystore |
| `ANDROID_KEY_ALIAS` | `perfinance` |
| `ANDROID_KEY_PASSWORD` | Clave de la llave |
| `GDRIVE_CLIENT_ID` | Client ID OAuth |
| `GDRIVE_CLIENT_SECRET` | Client secret OAuth |
| `GDRIVE_REFRESH_TOKEN` | Refresh token |
| `GDRIVE_APK_FILE_ID` | ID de `perfinance.apk` |
| `GDRIVE_MANIFEST_FILE_ID` | ID de `version.json` |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN` | Igual que `dart_defines.json` |
