# Arquitectura

## Visión general

TenisAmigos es un **monolito móvil** con backend administrado (Supabase). No
usa microservicios. La app se organiza **por funcionalidades (features)**, con
responsabilidades separadas.

## Stack

| Capa | Tecnología | Notas |
|------|------------|-------|
| UI | Flutter + Dart | Android e iOS (iOS no compila en Windows) |
| Estado | Riverpod | `flutter_riverpod` 3.x |
| Navegación | GoRouter | `StatefulShellRoute` para las 4 secciones |
| Fechas | `intl` | Formato en español (`es`) |
| Backend | Supabase (PostgreSQL + Auth + Storage) | A partir de la Etapa 2 |
| Imágenes | `image_picker` | Selección de la foto de perfil |

## Capas por feature

Cada funcionalidad agrupa lo que necesita; **no se crean carpetas vacías**:

- **presentation**: pantallas, widgets y providers de estado de interfaz.
- **domain**: modelos y reglas de negocio (por ejemplo, reglas de un partido).
- **data**: repositorios y acceso a datos (mock o Supabase según la etapa).

La interfaz **no** ejecuta consultas directas a la base de datos: siempre pasa
por un repositorio. Esto permite cambiar el mock por Supabase sin tocar las
pantallas.

## Flujo de dependencias

```
presentation  →  data (repositorio)  →  Supabase
      │
      └──────────→  domain (modelos/reglas)
```

## Navegación

`lib/app/router.dart` define:

- `StatefulShellRoute.indexedStack` con cuatro ramas (Inicio, Invitaciones,
  Amigos, Perfil) para conservar el estado de cada pestaña.
- Rutas de detalle y creación (`/partido/:id`, `/nuevo-partido`) fuera del
  shell, para que se abran por encima sin barra inferior.
- Rutas de autenticación (`/login`, `/registro`, `/recuperar-contrasena`,
  `/restablecer-contrasena`) y edición de perfil (`/perfil/editar`).
- El `redirect` protege las rutas sin sesión, evita que un usuario autenticado
  vuelva a login/registro y fuerza `/restablecer-contrasena` mientras haya un
  evento `passwordRecovery` pendiente.
- `refreshListenable` combina el cambio de sesión con `AuthLinkEvents.latest`.

## Decisiones registradas

- **Riverpod 3.4.3**: los providers son *autoDispose = false* por defecto; el
  estado se cachea. `AsyncValue.value` es la forma de leer el valor actual.
- **Datos mock aislados**: los que quedan (partidos, invitaciones y calendario)
  viven en `data/mock_*_repository.dart` y en `core/constants/mock_data.dart`,
  claramente marcados. Se eliminarán al conectar esas etapas a Supabase.
- **Identidad de usuario**: el usuario actual se referencia por `id`, nunca por
  correo o nombre. Desde la Etapa 2 es el `id` de Supabase Auth.
- **Localización**: la app fuerza `es` y usa `flutter_localizations` +
  `initializeDateFormatting('es')`.
- **Configuración**: `.env` se empaqueta como asset y se lee con
  `flutter_dotenv`. `AppConfig` expone las claves de Supabase y los client IDs
  de Google. El archivo está en `.gitignore`.
- **Autenticación**: las pantallas solo llaman a `AuthController`; este usa
  `GoogleAuthService` (token nativo), `AuthRepository` (sesión de Supabase) y
  `ProfileRepository` (perfil). Ninguna pantalla accede a Supabase directamente.
- **Google OAuth**: Google Sign-In 7.x obtiene un ID token y se canjea con
  `signInWithIdToken` de Supabase. En Android se usa el Web Client ID como
  `serverClientId`; el cliente Android se valida por package name + SHA-1.
- **Correo/contraseña**: `signUp` envía `full_name` en los metadatos y usa
  `emailRedirectTo`. Si Supabase exige confirmación no devuelve sesión y la app
  muestra "Revisa tu correo"; si no, inicia sesión directamente.
- **Recuperación**: `resetPasswordForEmail` usa el esquema propio
  `tenisamigos://auth-callback`. `AuthLinkEvents` escucha `onAuthStateChange`
  desde `main` para no perder el evento `passwordRecovery` durante el arranque.
  La pantalla de nueva contraseña limpia el evento al guardar o cancelar.
- **Errores de auth**: el repositorio traduce códigos de Supabase (credenciales,
  correo sin confirmar, contraseña débil, rate limit, enlace expirado, etc.) a
  `AppFailure` con mensajes en español.
- **Perfil**: nombre, nivel y mano dominante se guardan en `profiles`. Los
  enums `TennisLevel` y `DominantHand` usan claves estables (`beginner`,
  `right`, etc.) y etiquetas en español; los valores antiguos se normalizan en
  la migración.
- **Foto de perfil**: se sube al bucket público `avatars` en
  `<user-id>/avatar-<timestamp>.<ext>` y se guarda la URL pública en
  `profiles.avatar_url`. Las políticas RLS limitan la escritura a la carpeta del
  usuario. Se usa `upsert: false` porque el bucket no tiene política SELECT: la
  sobrescritura, el listado y el borrado desde el cliente requieren ese permiso.
  Los nombres únicos evitan colisiones sin necesidad de sobrescribir.
- **Amistades**: una fila por pareja con índice único sobre
  `(least(user_id, friend_id), greatest(user_id, friend_id))` y estados
  `pending`, `accepted` y `rejected`. El cliente solo lee sus filas; enviar,
  responder y cancelar pasa por RPC `SECURITY DEFINER`, y se revocan los permisos
  de escritura directa. Para agregar se busca por correo exacto, sin directorio
  público. La invitación por enlace queda pendiente de una URL pública de la app.
  El provider de amigos depende de `authControllerProvider` para no reutilizar
  los datos de otra cuenta tras cerrar e iniciar sesión.
- **RLS de perfiles**: además del perfil propio, amigos aceptados y personas con
  partidos en común, se permite ver el perfil de quien tiene una solicitud
  pendiente con el usuario. Así el receptor puede aceptar o rechazar.
- **Sesión**: Supabase restaura la sesión al iniciar. El router decide la
  pantalla inicial de forma perezosa, después de `Supabase.initialize`.
- **Validadores y pruebas**: `AuthValidators` centraliza las reglas de los
  formularios. Las pruebas cubren validadores, enums, navegación, formularios y
  reglas de partidos.

## Pendiente (etapas siguientes)

- Partidos, invitaciones y reglas de negocio en backend (Etapas 4-5).
- Invitación de amistades por enlace, cuando exista una URL pública de la app.
- Notificaciones push (Etapa 6).
- Opcional: política SELECT para que el dueño pueda listar, borrar o
  sobrescribir sus fotos desde el cliente.
