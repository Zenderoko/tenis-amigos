# Hoja de ruta

Estado de las etapas del proyecto. **No se avanza de etapa sin aprobación.**

| Etapa | Descripción | Estado |
|-------|-------------|--------|
| 0 | Preparación y planificación del entorno | ✅ Completada |
| 1 | Esqueleto de la app (navegación, tema, pantallas) | ✅ Completada |
| 2 | Supabase y autenticación | ✅ Completada |
| 3 | Amigos | ✅ Completada |
| 4 | Partidos | ⬜ Pendiente |
| 5 | Calendario y reprogramación | ⬜ Pendiente |
| 6 | Notificaciones | ⬜ Pendiente |
| 7 | Validación del MVP | ⬜ Pendiente |

## Etapa 0 — Preparación (completada)

- Flutter actualizado a 3.47.7 (Dart 3.13.5).
- Android SDK 36 + build-tools instalados; licencias aceptadas.
- `git init` en el proyecto.
- Verificado que un APK de prueba compila pese al aviso de espacios en la ruta
  del SDK (no bloquea; solo afecta a herramientas NDK, que no usamos).

## Etapa 1 — Esqueleto (completada)

Entregado:

- Proyecto Flutter (Android, iOS, web).
- Navegación con GoRouter y barra inferior de cuatro secciones.
- Tema visual (verde de pista, amarillo de pelota, arcilla).
- Pantallas: Inicio, Calendario (semana), Amigos, Perfil, Detalle de partido y
  Nuevo partido (formulario con validaciones).
- Estados de carga, vacío y error reutilizables.
- Widgets y utilidades en `core/`.
- Pruebas: reglas de negocio de partidos, formateo de fechas, avatares y
  navegación.
- Documentación: `README.md`, `docs/architecture.md`.

Verificación ejecutada: `flutter analyze` (sin issues), `flutter test`
(14 pruebas), `flutter build web` y `flutter build apk --debug` (ambos OK).

Todos los datos mostrados son **ficticios** (marcados con un aviso de
prototipo en pantalla).

## Etapa 2 — Supabase y autenticación (completada)

Hecho:

- Proyecto Supabase y configuración local con `.env` + `flutter_dotenv`.
- Esquema PostgreSQL versionado con migraciones y RLS.
- Registro e inicio de sesión con Google (Google Sign-In + Supabase Auth).
- Creación automática del perfil en `public.profiles`.
- Perfil real con nombre y foto de Google; el saludo de Inicio usa el nombre.
- Persistencia de sesión y cierre de sesión.
- Manejo de cancelación del flujo de Google y navegación de vuelta.
- Corrección de la recursión de políticas RLS que impedía leer perfiles.
- Registro e inicio de sesión con correo y contraseña.
- Detección de correo ya registrado al crear una cuenta.
- Confirmación de correo con reenvío del enlace desde la app.
- Recuperación de contraseña mediante enlace profundo
  (`tenisamigos://auth-callback`).
- Cambio de contraseña desde Perfil, verificando la contraseña actual.
- Edición del perfil: nombre, foto, nivel y mano dominante.
- Foto de perfil en Supabase Storage (bucket `avatars` con RLS por carpeta).
- Subida con nombres únicos y sin `upsert`, porque el bucket no tiene política
  SELECT y el modo sobrescritura era rechazado por RLS.
- Validadores compartidos y pruebas de auth, perfil y navegación.

Verificación E2E en Android (completada):

- [x] Inicio de sesión con Google y creación del perfil real.
- [x] Persistencia de la sesión tras reiniciar la app y cierre de sesión.
- [x] Login inválido con mensaje "Correo o contraseña incorrectos.".
- [x] Registro con confirmación de correo activa y pantalla "Revisa tu correo".
- [x] Reenvío del enlace con manejo del límite de intentos.
- [x] Solicitud del enlace de recuperación de contraseña.
- [x] Edición del perfil (nivel y mano dominante) persistida en Supabase.
- [x] Subida de la foto de perfil al bucket `avatars` y guardado de la URL.

Notas de la verificación:

- El clic final de los enlaces de confirmación y recuperación requiere abrir el
  buzón real del usuario; la app mostró correctamente las pantallas previas.
- El cambio de contraseña está cubierto por pruebas automatizadas. No se ejecutó
  en Android con la cuenta de Google porque esa cuenta no tiene contraseña, y el
  correo de prueba quedó sin confirmar por el límite de reenvíos.

Verificación automatizada: `flutter analyze` sin issues, `flutter test` con 37
pruebas aprobadas, `flutter build apk --debug` y `flutter build web` correctos.

Criterio de cierre: cumplido. Las vías de acceso con Google y con
correo/contraseña funcionan, la recuperación y el cambio de contraseña están
disponibles, el perfil se puede editar y las pruebas de la etapa pasan.

## Etapa 3 — Amigos (completada)

Hecho:

- Migración `20261103000000_friendships.sql` aplicada: una fila por pareja con
  índice único normalizado, sin autosolicitudes y con `responded_at`.
- RLS: el cliente solo lee sus relaciones; las mutaciones se hacen con RPC
  `SECURITY DEFINER` (`send_friend_request_by_email`,
  `respond_friend_request`, `cancel_friend_request`).
- Los perfiles de solicitudes pendientes son visibles para poder aceptarlas o
  rechazarlas, conservando la visibilidad de amigos aceptados y partidos.
- Búsqueda de personas por correo exacto, sin directorio público.
- Pantalla de Amigos real: solicitudes recibidas, solicitudes enviadas,
  aceptar, rechazar, cancelar y listado de amigos con foto y nivel.
- Perfil de amigo al tocar una tarjeta, con nivel, mano dominante y eliminación
  de la amistad con confirmación.
- La eliminación borra la fila única y afecta a ambos. El cliente escucha
  `friendships` por Supabase Realtime para refrescar las dos listas.
- Migración `20261103000001_remove_friend_realtime.sql` aplicada: RPC
  `remove_friend`, `replica identity full` y publicación en Realtime.
- Estado vacío con acción para agregar al primer amigo y refresco manual.
- Pruebas de mapeo de amistades, perfil, eliminación y Realtime (14 nuevas;
  51 en total).
- Documentación actualizada.

Verificación E2E en Android (completada):

- [x] Estado vacío real y carga desde Supabase.
- [x] Error claro al buscar un correo sin cuenta.
- [x] Bloqueo de autosolicitud.
- [x] Envío, detección de solicitud duplicada y cancelación.
- [x] Rechazo de una solicitud recibida: desaparece de la lista.
- [x] Aceptación: la persona pasa a "Mis amigos" con su perfil.
- [x] Limpieza de los datos de prueba y vuelta al estado vacío.

La cuenta secundaria `amonsalveru+e2e@gmail.com` sigue sin confirmar, así que
para aceptar/rechazar se insertó una solicitud pendiente real desde el SQL
Editor. El envío, duplicado y cancelación se probaron desde la app con la cuenta
principal. Las RPC y las políticas RLS se ejercitaron en ambos sentidos.

Verificación E2E de perfil, eliminación y Realtime (completada):

- [x] Abrir el perfil de un amigo desde la lista, con nivel y mano visibles.
- [x] Eliminar la amistad desde el perfil con confirmación; la lista quedó
  vacía y la consulta REST confirmó que no quedan filas.
- [x] Realtime: una solicitud creada externamente por REST apareció sin
  refrescar y desapareció al cancelarla.
- [x] La relación es una fila única compartida, así que su eliminación deja de
  existir para ambos usuarios.

La cuenta secundaria `amonsalveru+e2e@gmail.com` sigue sin confirmar, así que no
se observó el evento en una segunda sesión. La eliminación se validó por la fila
única compartida y la consulta REST; Realtime se validó con un cambio externo
recibido en la app sin refrescar.

Pendiente fuera del criterio de cierre:

- Invitación mediante enlace: diferida porque la app aún no tiene una URL
  pública de descarga ni un enlace de invitación propio.

Verificación automatizada: `flutter analyze` sin issues, `flutter test` con 51
pruebas aprobadas, `flutter build apk --debug` y `flutter build web` correctos.

Criterio de cierre: cumplido. Las solicitudes se envían, se aceptan o rechazan,
la lista de amigos se actualiza y las políticas impiden agregar amistades sin
consentimiento.
