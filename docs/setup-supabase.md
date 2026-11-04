# Configuración de Supabase, correo y Google OAuth

Esta guía deja el proyecto listo para registrarse e iniciar sesión con Google o
con correo/contraseña, confirmar el correo y recuperar la contraseña. Los IDs
concretos del entorno están en `google_oauth_config.txt` (archivo local, no
versionado) y en `.env`.

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
5. `supabase/migrations/20261101000000_profile_fields_and_avatars.sql`
6. `supabase/migrations/20261103000000_friendships.sql`
7. `supabase/migrations/20261103000001_remove_friend_realtime.sql`

La tercera migración crea un trigger en `auth.users` que inserta el perfil en
`public.profiles` automáticamente al registrar una cuenta (incluido Google).
La cuarta corrige una recursión infinita de las políticas RLS que impedía
consultar `profiles`. La quinta normaliza los valores de nivel y mano dominante,
añade restricciones de validación y crea el bucket `avatars` con sus políticas.
La sexta normaliza las amistades (una fila por pareja, sin autosolicitudes),
limita la escritura directa y crea las RPC para enviar, aceptar/rechazar y
cancelar solicitudes. Depende de las funciones `are_friends` y `share_match` de
la cuarta migración, así que respeta el orden. La séptima añade la RPC
`remove_friend`, configura `replica identity full` y publica `friendships` en
`supabase_realtime` para que ambos usuarios vean los cambios sin refrescar. La
app también verifica el perfil después del login como respaldo.

## 3) Correo, confirmación y enlaces profundos

En Supabase → **Authentication → URL Configuration**:

1. **Site URL**: la URL web del proyecto o `http://localhost:3000` en
   desarrollo.
2. **Redirect URLs**: añade exactamente
   `tenisamigos://auth-callback` (Android/iOS) y, si usas web, la URL del
   origen (por ejemplo `http://localhost:3000/`).

En **Authentication → Providers → Email**:

1. Verifica que el proveedor esté habilitado.
2. Decide si **Confirm email** estará activo. Si lo está, tras registrarse la
   app muestra la pantalla "Revisa tu correo" y permite reenviar el enlace.
3. Revisa las plantillas **Confirm signup** y **Reset password**. Deben incluir
   el enlace `{{ .ConfirmationURL }}` que Supabase genera con la Redirect URL.

El esquema `tenisamigos` está registrado en
`android/app/src/main/AndroidManifest.xml` y en `ios/Runner/Info.plist`. Al
abrir el enlace, Supabase procesa el `code` y la app muestra la pantalla para
crear la contraseña nueva.

## 4) Credenciales en Google Cloud

Entra a [Google Cloud Console](https://console.cloud.google.com/) → **APIs &
Services → Credentials** y crea dos OAuth client IDs.

### a) Cliente Web (obligatorio)

- Tipo: **Web application**
- Nombre: `TenisAmigos Web`
- **Authorized redirect URIs**:
  `https://<project-ref>.supabase.co/auth/v1/callback`
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

## 5) Proveedor Google en Supabase

En Supabase → **Authentication → Providers → Google**:

1. Activa el proveedor.
2. Pega el **Client ID** del cliente Web.
3. Pega el **Client Secret** del cliente Web (solo está en Google Cloud; no se
   guarda en el repositorio).
4. Guarda los cambios.

## 6) Variables locales

En `.env`:

```env
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<publishable-key>
GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=<android-client-id>.apps.googleusercontent.com
```

`.env` se incluye como asset en tiempo de compilación y está en `.gitignore`.
El código lo lee con `flutter_dotenv` en `lib/main.dart`.

## 7) Emulador Android

El flujo de Google necesita una cuenta de Google en el dispositivo:

1. Abre **Settings → Passwords & accounts → Add account → Google** en el
   emulador.
2. Inicia sesión con una cuenta real.
3. Usa una imagen de emulador con **Google Play Services** (por ejemplo,
   Pixel API 35).

## 8) Storage de fotos de perfil

La migración `20261101000000_profile_fields_and_avatars.sql` crea el bucket
público `avatars` con límite de 5 MB y tipos `image/jpeg`, `image/png`,
`image/webp`, `image/gif` e `image/heic`. Las políticas permiten escribir solo
dentro de la carpeta con el id del usuario (`<user-id>/...`) y la lectura
pública se hace por URL.

Si el bucket ya existe, la migración actualiza su configuración y las políticas
sin borrar los archivos.

La app sube cada foto con un nombre único (`avatar-<timestamp>`) y sin
sobrescribir. Las políticas actuales no incluyen SELECT para el dueño, así que
listar, borrar o reemplazar archivos desde el cliente requiere añadir esa
política en el dashboard.

## 9) Amigos

La migración `20261103000000_friendships.sql` busca a la otra persona por su
correo exacto en `auth.users` y usa su perfil de `public.profiles`. No hay un
directorio público de usuarios: para agregar a alguien necesitas su correo.

La app no escribe directamente en `friendships`. Las operaciones pasan por
`send_friend_request_by_email`, `respond_friend_request`,
`cancel_friend_request` y `remove_friend`, que comprueban quién envía, quién
responde y el estado de la solicitud. Al tocar un amigo se abre su perfil y
desde ahí se puede eliminar la amistad; la fila única desaparece para ambos.

La séptima migración también publica `friendships` en Supabase Realtime. Si la
lista no se actualiza sola cuando la otra persona envía, acepta o elimina una
amistad, revisa que esa migración se haya aplicado y que la tabla aparezca en
la publicación `supabase_realtime`.

## 10) Ejecutar

```powershell
flutter pub get
flutter run -d emulator-5554 --debug
```

En el primer inicio de sesión Supabase crea el usuario en `auth.users` y la app
guarda su perfil en `public.profiles` con nombre y foto. Con correo/contraseña,
si la confirmación está activa, el usuario debe abrir el enlace del correo antes
de entrar. La recuperación de contraseña abre la app mediante
`tenisamigos://auth-callback`.

## Problemas frecuentes

| Síntoma | Causa probable |
|---------|----------------|
| `clientConfigurationError` | SHA-1 o package name incorrectos en el cliente Android. |
| `providerConfigurationError` | Google Play Services no disponible o cliente mal configurado. |
| `provider is not enabled` | El proveedor Google no está activo en Supabase. |
| `invalid token` | El `GOOGLE_WEB_CLIENT_ID` no coincide con el de Supabase. |
| `Could not find the table 'public.profiles'` | Faltan las migraciones. |
| No aparece ninguna cuenta | El emulador no tiene una cuenta de Google añadida. |
| El enlace de correo no vuelve a la app | Falta `tenisamigos://auth-callback` en Redirect URLs. |
| `No encontramos el bucket avatars` | Falta aplicar la quinta migración. |
| `new row violates row-level security policy` al subir la foto | El cliente intenta sobrescribir (`upsert`) o listar/borrar sin política SELECT; la app actual sube con `upsert: false`. |
| `Could not find the function public.send_friend_request_by_email` | Falta aplicar la sexta migración. |
| `Could not find the function public.remove_friend` | Falta aplicar la séptima migración. |
| `permission denied for table friendships` | El cliente intenta escribir directamente; usa las RPC de las migraciones sexta y séptima. |
| La solicitud de amistad no aparece | El receptor debe confirmar su correo y tener perfil; revisa que el correo sea exacto. |
| La lista de amigos no se actualiza sola | Falta aplicar la séptima migración o `friendships` no está en la publicación `supabase_realtime`. |
| El correo de confirmación no llega | Revisa el proveedor Email y la bandeja de spam. |
