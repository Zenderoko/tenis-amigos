# Reglas de negocio de partidos

Este documento define el comportamiento de la Etapa 4. La cancelación, la
reprogramación, el calendario definitivo y el historial completo se completan en
la Etapa 5.

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
- `cancelled`: reservado para la Etapa 5.
- `completed`: reservado para la Etapa 5/7.

Un partido se crea en `awaiting_players` porque las invitaciones están
pendientes. Cuando la cantidad de respuestas `accepted` alcanza el cupo total, el
partido pasa a `confirmed`. Un rechazo no cancela el partido: el organizador
puede invitar a otra persona.

## Respuestas de los jugadores

- `invited`: invitación pendiente.
- `accepted`: jugador confirmado.
- `declined`: el jugador rechazó la invitación.
- `withdrawn`: reservado para la Etapa 5.

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

## Concurrencia

- Las RPC bloquean las filas relevantes con `for update`.
- Cada cambio de estado del partido incrementa `matches.version`.
- Las operaciones que cambian respuestas o estado se validan en el backend, no
  solo en la interfaz.
- La tabla `match_participants` mantiene una fila única por `(match_id,
  user_id)`.

## Seguridad

- El cliente no escribe directamente en `matches`, `match_participants` ni
  `match_events`; usa RPC `SECURITY DEFINER`.
- Solo el organizador puede crear un partido e invitar jugadores.
- Solo un participante puede consultar el detalle y la lista de jugadores de su
  partido.
- Solo el invitado puede responder su propia invitación.
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

Fuera de alcance:

- Cancelar partidos.
- Proponer, aceptar o rechazar reprogramaciones.
- Retirarse de un partido ya confirmado.
- Vista de calendario rediseñada y recordatorios push.
