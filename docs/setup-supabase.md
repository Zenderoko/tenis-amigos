# Configuración de Supabase y Google OAuth

Esta guía deja el proyecto listo para registrarse e iniciar sesión con Google.
Los IDs concretos del entorno están en `google_oauth_config.txt` (archivo local,
no versionado) y en `.env`.

## 1) Proyecto Supabase

1. Ve a [supabase.com](https://supabase.com) y crea o abre el proyecto.
2. En **Settings → API** copia:
   - **Project URL** → `SUPABASE_URL`
   - **Publishable key** → `SUPABASE_PUBLISHABLE_KEY`
3. Copia `.env.example` a `.env` y completa esos valores.

## 2) Migraciones

En **SQL Editor** ejecuta, en este orden:

1. `supabase/migrations/20261028000000_init_schema.sql`
2. `supabase/migrations/20261028000001_rls_policies.sql`
3. `supabase/migrations/20261030000000_profile_on_signup.sql`
4. `supabase/migrations/20261030000001_fix_rls_recursion.sql`

La tercera migración crea un trigger en `auth.users` que inserta el perfil en
`public.profiles` automáticamente al registrar una cuenta (incluido Google).
La cuarta corrige una recursión infinita de las políticas RLS que impedía
consultar `profiles`. La app también verifica el perfil después del login como
respaldo.

## 3) Credenciales en Google Cloud

Entra a [Google Cloud Console](https://console.cloud.google.com/) → **APIs &
Services → Credentials** y crea dos OAuth client IDs.

### a) Cliente Web (obligatorio)

- Tipo: **Web application**
- Nombre: `TenisAmigos Web`
- **Authorized redirect URIs**:
  `https://<project-ref>.supabase.co/auth/v1/callback`
  (por ejemplo, `https://slvrkhtoqkcbxlpvvotq.supabase.co/auth/v1/callback`)
- Copia el **Client ID** → `GOOGLE_WEB_CLIENT_ID`

Este Client ID se usa como `serverClientId` en Android y debe ser el mismo que
se configure en Supabase.

### b) Cliente Android (obligatorio)

- Tipo: **Android**
- Nombre: `TenisAmigos Android`
- **Package name**: `com.tenisamigos.tenis_amigos`
- **SHA-1 certificate fingerprint**: el valor de `google_oauth_config.txt`
  (`F0:AA:C4:5C:97:11:3D:9B:24:5A:48:69:03:A6:46:CB:BE:24:23:FE`)
- Copia el **Client ID** → `GOOGLE_ANDROID_CLIENT_ID`

El Client ID de Android se vincula al SHA-1 y al package name. La app no lo envía
desde Dart; Google lo resuelve en el dispositivo.

> Si cambias de keystore (por ejemplo, al firmar release), debes registrar el
> nuevo SHA-1 en este mismo cliente de Android.

## 4) Proveedor Google en Supabase

En Supabase → **Authentication → Providers → Google**:

1. Activa el proveedor.
2. Pega el **Client ID** del cliente Web.
3. Pega el **Client Secret** del cliente Web (solo está en Google Cloud; no se
   guarda en el repositorio).
4. Guarda los cambios.

## 5) Variables locales

En `.env`:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<publishable-key>
GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=<android-client-id>.apps.googleusercontent.com
```

`.env` se incluye como asset en tiempo de compilación y está en `.gitignore`.
El código lo lee con `flutter_dotenv` en `lib/main.dart`.

## 6) Emulador Android

El flujo de Google necesita una cuenta de Google en el dispositivo:

1. Abre **Settings → Passwords & accounts → Add account → Google** en el
   emulador.
2. Inicia sesión con una cuenta real.
3. Usa una imagen de emulador con **Google Play Services** (por ejemplo,
   Pixel API 35).

## 7) Ejecutar

```powershell
flutter pub get
flutter run -d emulator-5554 --debug
```

En el primer inicio de sesión Supabase crea el usuario en `auth.users` y la app
guarda su perfil en `public.profiles` con nombre y foto de Google.

## Problemas frecuentes

| Síntoma | Causa probable |
|---------|----------------|
| `clientConfigurationError` | SHA-1 o package name incorrectos en el cliente Android. |
| `providerConfigurationError` | Google Play Services no disponible o cliente mal configurado. |
| `provider is not enabled` | El proveedor Google no está activo en Supabase. |
| `invalid token` | El `GOOGLE_WEB_CLIENT_ID` no coincide con el de Supabase. |
| `Could not find the table 'public.profiles'` | Faltan las migraciones. |
| No aparece ninguna cuenta | El emulador no tiene una cuenta de Google añadida. |
