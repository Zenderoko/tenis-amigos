# Hoja de ruta

Estado de las etapas del proyecto. **No se avanza de etapa sin aprobación.**

| Etapa | Descripción | Estado |
|-------|-------------|--------|
| 0 | Preparación y planificación del entorno | ✅ Completada |
| 1 | Esqueleto de la app (navegación, tema, pantallas) | ✅ Completada |
| 2 | Supabase y autenticación | ✅ Completada |
| 3 | Amigos | ✅ Completada |
| 4 | Partidos | ✅ Completada |
| 5 | Calendario y reprogramación | ✅ Completada |
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

## Etapa 4 — Partidos (completada)

Hecho en código:

- Reglas de negocio documentadas en `docs/business-rules.md`.
- Migración `20261104000000_matches.sql` creada con las RPC `create_match`,
  `respond_match_invitation` e `invite_match_players`, validaciones de
  modalidad, cupo, fecha, duración, lugar, amistad y concurrencia.
- Escrituras directas revocadas; las mutaciones pasan por RPC
  `SECURITY DEFINER`.
- Política de `match_participants` corregida para que todos los jugadores del
  partido puedan verse entre sí.
- Realtime para `matches` y `match_participants`; la lista y el detalle se
  refrescan al cambiar una invitación o un cupo.
- Modelo de partido ampliado con organizador, zona horaria, versión, cupos,
  invitaciones pendientes y valores de base de datos.
- Repositorio Supabase real y providers con acciones de crear, responder e
  invitar.
- Formulario de creación seccionado con selector de amistades aceptadas.
- Invitaciones reales con aceptar/rechazar desde la lista y el detalle.
- Detalle real con jugadores, respuestas, fotos, nivel, cupo e historial de
  eventos.
- El organizador puede invitar jugadores adicionales o reemplazos desde el
  detalle.
- Tarjetas rediseñadas con cupo/pendientes, avatares y estado.
- Se retiraron los datos mock, el aviso de prototipo y las pantallas basadas en
  `kMockCurrentUserId`.
- Horarios en UTC convertidos a `America/Santiago` con `timezone`; pruebas de
  invierno/verano.
- Pruebas nuevas de cupos, respuestas y valores de base de datos (59 en total).
- `flutter analyze` sin hallazgos y builds Android debug y web completados.
- Migración aplicada en Supabase SQL Editor.

Verificación E2E de backend (completada):

- `supabase/tests/stage4_e2e.sql` ejecutado en el SQL Editor: las 28
  comprobaciones salieron en `ok = true` (usuarios/amistad, RLS, creación de
  singles y dobles, aceptar/rechazar, reinvitación, validaciones negativas y
  Realtime).

Verificación E2E en Android (completada):

- [x] Crear un singles desde la app e invitar a la cuenta E2E.
- [x] Realtime: al aceptar la invitación desde el SQL Editor con la sesión
  simulada de la cuenta E2E, el detalle cambió a `2/2 confirmados` y
  `Confirmado` sin refrescar.
- [x] Crear un dobles e invitar a la cuenta E2E.
- [x] Rechazo por Realtime: el detalle mostró `Rechazado`, `1/4 confirmados` y
  `3 plazas libres`.
- [x] Reinvitar al reemplazo desde el detalle; la app volvió a mostrar
  `Invitado`, `1 pendiente` y `2 plazas libres`.
- [x] Aceptación por Realtime: el dobles quedó `2/4 confirmados` con
  `2 plazas libres`.
- [x] Bandeja de invitaciones: la cuenta E2E creó un singles inverso desde SQL
  y la app primaria mostró la invitación; al pulsar `Aceptar` desapareció de
  la bandeja y el partido apareció en Inicio como confirmado.
- [x] Emulador usado: AVD `flutter_emulator`, ID ADB `emulator-5554`.

Notas de la verificación:

- La cuenta secundaria `amonsalveru+e2e@gmail.com` sigue sin confirmar. Sus
  respuestas (aceptar/rechazar/reinvitar) se ejecutaron desde el SQL Editor con
  `request.jwt.claim.sub`/`request.jwt.claims`, y la app primaria recibió los
  cambios por Realtime. No se abrió una segunda sesión de UI para la secundaria.
- Los partidos y la amistad de prueba quedaron creados en la cuenta primaria
  para futuras pruebas.

Verificación automatizada: `flutter analyze` sin issues, `flutter test` con 59
pruebas aprobadas, `flutter build apk --debug` y `flutter build web` correctos.

Criterio de cierre: cumplido. La app crea singles y dobles, invita amistades,
acepta/rechaza invitaciones, reinvita reemplazos y refleja cupos/estados por
Realtime.

## Etapa 5 — Calendario y reprogramación (completada)

Hecho en código:

- Reglas de negocio ampliadas en `docs/business-rules.md` (cancelación, retiro y
  reprogramación).
- Migración `20261105000000_cancel_reschedule.sql` creada con las RPC
  `cancel_match`, `withdraw_from_match`, `propose_reschedule`,
  `respond_reschedule` y `cancel_reschedule`, y la tabla
  `match_proposal_votes`.
- Escrituras directas revocadas sobre `match_proposals` y
  `match_proposal_votes`; las mutaciones pasan por RPC `SECURITY DEFINER`.
- Tipos de evento `withdrawn` y `reschedule_rejected`; propuestas publicadas en
  Realtime (además de incrementar `matches.version`).
- Modelo de partido ampliado con `MatchProposal`, `MatchProposalStatus`,
  `MatchProposalVote` y helpers de acciones (cancelar, retirar, proponer,
  aprobar/rechazar).
- Repositorio y providers con las acciones de cancelación, retiro y
  reprogramación.
- Detalle del partido con cancelación (organizador), retiro (jugador
  confirmado), propuesta de nuevo horario y aprobación/rechazo con conteo de
  votos; confirmaciones antes de acciones destructivas.
- Calendario rediseñado con vistas semanal y mensual, indicadores por estado por
  día y leyenda; el historial muestra los eventos nuevos.
- Ventana de Partidos (antes Invitaciones) con pestañas En curso, Invitaciones e
  Historial; las invitaciones pendientes se ven junto a los partidos activos y
  el historial incluye finalizados y cancelados.
- El organizador puede eliminar a un jugador que no podrá asistir (migración
  `20261106000000_remove_player.sql`, RPC `remove_match_player`, estados
  `removed` y evento `removed`).
- Pruebas nuevas de propuestas y acciones (10 en total; 76 en total).
- `flutter analyze` sin hallazgos y `flutter test` con 76 pruebas aprobadas.

Verificación E2E (completada):

- [x] Aplicar `20261105000000_cancel_reschedule.sql` en el SQL Editor.
- [x] Ejecutar `supabase/tests/stage5_e2e.sql` (todas las filas en `ok = true`).
- [x] Cancelar un partido desde la app y comprobar el estado y el evento.
- [x] Retirarse de un partido confirmado y ver el cupo liberado.
- [x] Proponer un nuevo horario y aprobarlo/rechazarlo por Realtime.
- [x] Revisar el calendario en vista semanal y mensual.
- [x] Aplicar `20261106000000_remove_player.sql` en el SQL Editor.
- [x] Ejecutar `supabase/tests/remove_player_e2e.sql` (todas las filas en
      `ok = true`).
- [x] Eliminar a un jugador desde el detalle y ver el cupo liberado.

Notas:

- La política de reprogramación es: solo el organizador propone; deben aprobar
  todos los jugadores confirmados y un rechazo la descarta.
- Los cambios de propuesta incrementan `matches.version`, por lo que el Realtime
  ya suscrito refresca la interfaz sin canales adicionales.

Criterio de cierre: cumplido. La migración se aplicó en Supabase, los E2E de
backend pasaron (`stage5_e2e.sql` y `remove_player_e2e.sql`) y el flujo se
verificó en el emulador `flutter_emulator` (`emulator-5554`).

## Etapa 6 — Notificaciones (plan aprobado)

Decisiones:

- Solo avisos **in-app** completos; el push (FCM) queda con el andamiaje
  preparado, sin simularlo ni activarlo.
- Recordatorios previos al partido con **pg_cron** en Supabase.
- Los avisos se muestran con una **campana con badge** en Inicio y una pantalla
  **Avisos** dedicada.

Alcance:

Backend (migración nueva):

- Tabla `public.notifications` (`user_id`, `type`, `match_id`, `title`, `body`,
  `data`, `read_at`, `created_at`, `dedupe_key` único).
- Lógica separada de partidos: triggers sobre `match_participants`,
  `match_proposals` y `match_events` encolan los avisos.
- Anti-duplicados con `dedupe_key` único + `on conflict do nothing`.
- RLS de lectura propia; RPC `mark_notification_read(id)` y
  `mark_all_notifications_read()`; sin escritura directa del cliente.
- Realtime en `notifications`.
- Job de `pg_cron` para el recordatorio previo al partido.
- Andamiaje de push: tabla `device_tokens` + RPC `register_device_token`, sin
  activar FCM.

Frontend:

- `features/notifications/` (domain/data/presentation) con provider y Realtime.
- Campana con badge de no leídos y pantalla Avisos (marcar leído, abrir partido).
- Avisos dentro de la app (banner/snackbar) al llegar uno nuevo.
- `NotificationService` con implementación no-op tras un flag.

Eventos cubiertos: nueva invitación, invitación aceptada/rechazada, propuesta de
reprogramación, cambio de horario aprobado, cancelación, jugador eliminado y
recordatorio previo.

Pruebas y docs: unit tests (mapeo y dedupe), widget tests (lista y badge), E2E
SQL (triggers + dedupe) y actualización de `business-rules.md`,
`architecture.md`, `setup-supabase.md`, `README.md` y este roadmap.

Criterio de cierre: avisos in-app funcionando con dedupe verificado por E2E y el
andamiaje de push documentado sin afirmar que el push está activo.
