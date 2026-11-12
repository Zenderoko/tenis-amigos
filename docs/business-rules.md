# Reglas de negocio de partidos

Este documento define el comportamiento de las etapas 4 y 5. La cancelación, el
retiro, la reprogramación y el historial de eventos se completaron en la Etapa 5.
Las notificaciones y los recordatorios push quedan para la Etapa 6.

## Modalidades y cupos

- `singles`: 2 jugadores en total (el organizador y 1 invitado).
- `doubles`: 4 jugadores en total (el organizador y 3 invitados).
- El organizador siempre ocupa una plaza y queda con respuesta `accepted`.
- Al crear un partido se debe invitar al menos a 1 jugador y como máximo a
  `maxPlayers - 1`. Se permiten menos invitados que el cupo total para poder
  completar el partido desde el detalle.
- Solo se pueden invitar amistades aceptadas.
- No se puede invitar al organizador ni duplicar jugadores en el mismo partido.
- Un jugador que rechazó puede ser reemplazado. El organizador también puede
  volver a invitarlo actualizando su respuesta a `invited`.

## Estados del partido

- `awaiting_players`: faltan respuestas o plazas por cubrir.
- `confirmed`: todos los jugadores requeridos aceptaron.
- `cancelled`: el organizador canceló el partido (Etapa 5).
- `completed`: reservado para la Etapa 7.

Un partido se crea en `awaiting_players` porque las invitaciones están
pendientes. Cuando la cantidad de respuestas `accepted` alcanza el cupo total, el
partido pasa a `confirmed`. Un rechazo no cancela el partido: el organizador
puede invitar a otra persona. Si un jugador confirmado se retira, el partido
vuelve a `awaiting_players`.

## Respuestas de los jugadores

- `invited`: invitación pendiente.
- `accepted`: jugador confirmado.
- `declined`: el jugador rechazó la invitación.
- `withdrawn`: el jugador confirmado se retiró (Etapa 5).
- `removed`: el organizador eliminó al jugador (Etapa 5).

Solo el propio jugador puede aceptar o rechazar su invitación. La operación solo
es válida si el partido está activo (`awaiting_players` o `confirmed`) y su
respuesta sigue en `invited`.

## Fecha, hora y lugar

- `starts_at` se almacena en UTC (`timestamptz`).
- La zona horaria del partido se guarda en `timezone`. Para el MVP se usa
  `America/Santiago` y el cliente convierte con el paquete `timezone`, sin
  calcular el horario de verano a mano.
- La fecha y hora deben ser posteriores al momento de crear el partido.
- Duraciones permitidas: 60, 75, 90 y 120 minutos.
- El nombre del lugar es obligatorio; los detalles son opcionales.
- La API y las RPC vuelven a validar estas reglas; la interfaz solo las refleja.

## Invitaciones y reemplazos

- Las invitaciones se crean junto con el partido.
- El organizador puede invitar jugadores adicionales desde el detalle mientras
  el partido esté activo y queden plazas activas.
- Se cuentan como plazas activas las respuestas `invited` y `accepted`. Los
  rechazos no ocupan cupo y permiten invitar un reemplazo.
- Cada invitación genera un evento `invited` en `match_events`.

## Cancelación

- Solo el organizador puede cancelar un partido activo
  (`awaiting_players` o `confirmed`).
- Al cancelar, el partido pasa a `cancelled` y se descarta cualquier propuesta
  de reprogramación pendiente.
- No se puede cancelar un partido ya cancelado o finalizado.
- La cancelación registra un evento `cancelled`.

## Retiro de un jugador

- Un jugador confirmado (respuesta `accepted`) que no es el organizador puede
  retirarse de un partido activo.
- Al retirarse, su respuesta pasa a `withdrawn` y libera su plaza.
- Si el partido estaba `confirmed`, vuelve a `awaiting_players` para que el
  organizador pueda invitar un reemplazo.
- El organizador no puede retirarse: para dejarlo debe cancelar el partido.
- El retiro registra un evento `withdrawn`.

## Eliminar a un jugador

- El organizador puede eliminar a otro jugador activo (invitado o confirmado)
  que ya no podrá asistir.
- No puede eliminarse a sí mismo: para eso cancela el partido.
- Al eliminarlo, su respuesta pasa a `removed` y libera su plaza.
- Si el partido estaba `confirmed`, vuelve a `awaiting_players` para que el
  organizador pueda invitar un reemplazo.
- Sus votos en propuestas de reprogramación pendientes dejan de contar.
- La eliminación registra un evento `removed`.

## Reprogramación

- Solo el organizador propone un nuevo horario para un partido activo.
- La fecha oficial **no** cambia hasta que la propuesta se apruebe.
- Deben aprobar la propuesta todos los jugadores `accepted` distintos del
  organizador. Un solo rechazo descarta la propuesta.
- El proponente no vota su propia propuesta.
- Solo puede existir una propuesta pendiente por partido: una nueva propuesta
  reemplaza (`superseded`) a la anterior. El organizador también puede retirar
  la suya.
- Si no hay otros jugadores confirmados, la propuesta se aplica de inmediato.
- Al aprobarse, `matches.starts_at` y `timezone` se actualizan y se registra un
  evento `rescheduled`. Un rechazo registra un evento `reschedule_rejected`.

## Concurrencia

- Las RPC bloquean las filas relevantes con `for update`.
- Cada cambio de estado del partido incrementa `matches.version`.
- Las operaciones que cambian respuestas, propuestas o estado se validan en el
  backend, no solo en la interfaz.
- La tabla `match_participants` mantiene una fila única por `(match_id,
  user_id)`. La tabla `match_proposal_votes` mantiene una fila única por
  `(proposal_id, user_id)`.

## Seguridad

- El cliente no escribe directamente en `matches`, `match_participants`,
  `match_events`, `match_proposals` ni `match_proposal_votes`; usa RPC
  `SECURITY DEFINER`.
- Solo el organizador puede crear un partido, invitar jugadores, cancelarlo,
  eliminar jugadores y proponer/retirar reprogramaciones.
- Solo un participante puede consultar el detalle y la lista de jugadores de su
  partido.
- Solo el invitado puede responder su propia invitación; solo un jugador
  confirmado puede votar una reprogramación.
- Las políticas RLS y las RPC se validan en Supabase; no se usa la clave
  `service_role` en Flutter.

## Alcance de la Etapa 4

Incluido:

- Crear partidos con modalidad, fecha, hora, duración, lugar e invitados.
- Invitar amigos aceptados y completar el cupo desde el detalle.
- Aceptar o rechazar invitaciones.
- Consultar el detalle, los jugadores y su estado.
- Registrar eventos `created`, `invited` y `responded`.
- Sincronizar la lista y el detalle con Supabase Realtime.

## Alcance de la Etapa 5

Incluido:

- Cancelar partidos (organizador).
- Retirarse de un partido confirmado (jugador).
- Eliminar a un jugador del partido (organizador).
- Proponer, aprobar o rechazar reprogramaciones.
- Retirar una propuesta pendiente (organizador).
- Calendario con vista semanal y mensual, indicadores por estado y leyenda.
- Historial de eventos con `cancelled`, `withdrawn`, `removed`, `proposed`,
  `rescheduled` y `reschedule_rejected`.

Fuera de alcance:

- Recordatorios push y notificaciones externas (Etapa 6).
- Reservas reales de canchas, pagos, rankings o torneos.
