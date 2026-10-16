/// Enumeraciones y modelos de partidos.
///
/// Nota: en la Etapa 1 estos modelos se alimentan con datos ficticios. Su forma
/// se inspira en el esquema PostgreSQL que se definirá en la Etapa 2.
library;

/// Modalidad del partido y número de jugadores que admite.
enum MatchFormat {
  singles('Singles', 2),
  doubles('Dobles', 4);

  const MatchFormat(this.label, this.maxPlayers);

  /// Texto visible en español.
  final String label;

  /// Número total de jugadores que admite la modalidad.
  final int maxPlayers;
}

/// Estado de un partido.
///
/// - [awaitingPlayers]: falta confirmar jugadores.
/// - [confirmed]: cupo completo confirmado.
/// - [cancelled]: el organizador lo canceló.
/// - [completed]: el partido ya se jugó.
enum MatchStatus {
  awaitingPlayers('Faltan jugadores'),
  confirmed('Confirmado'),
  cancelled('Cancelado'),
  completed('Finalizado');

  const MatchStatus(this.label);

  final String label;
}

/// Respuesta de un jugador a su invitación.
enum ParticipantResponse {
  invited('Invitado'),
  accepted('Confirmado'),
  declined('Rechazado'),
  withdrawn('Retirado');

  const ParticipantResponse(this.label);

  final String label;
}

/// Tipo de evento del historial de un partido.
enum MatchEventType {
  created('Partido creado'),
  invited('Invitación enviada'),
  responded('Respuesta recibida'),
  proposed('Reprogramación propuesta'),
  rescheduled('Horario actualizado'),
  cancelled('Partido cancelado'),
  completed('Partido finalizado');

  const MatchEventType(this.label);

  final String label;
}

/// Un jugador dentro de un partido.
class MatchParticipant {
  const MatchParticipant({
    required this.id,
    required this.name,
    this.isOrganizer = false,
    this.response = ParticipantResponse.invited,
  });

  final String id;
  final String name;
  final bool isOrganizer;
  final ParticipantResponse response;

  MatchParticipant copyWith({ParticipantResponse? response}) {
    return MatchParticipant(
      id: id,
      name: name,
      isOrganizer: isOrganizer,
      response: response ?? this.response,
    );
  }
}

/// Evento del historial de un partido.
class MatchEvent {
  const MatchEvent({
    required this.type,
    required this.at,
    required this.description,
  });

  final MatchEventType type;
  final DateTime at;
  final String description;
}

/// Un partido de tenis.
class Match {
  const Match({
    required this.id,
    required this.format,
    required this.startsAt,
    required this.durationMinutes,
    required this.locationName,
    required this.status,
    required this.participants,
    this.locationDetails,
    this.events = const <MatchEvent>[],
  });

  final String id;
  final MatchFormat format;

  /// Inicio del partido. En la Etapa 1 se usa hora local; más adelante se
  /// almacenará en UTC conservando la zona horaria del partido.
  final DateTime startsAt;
  final int durationMinutes;
  final String locationName;
  final String? locationDetails;
  final MatchStatus status;
  final List<MatchParticipant> participants;
  final List<MatchEvent> events;

  /// Jugadores que ya confirmaron su asistencia.
  int get confirmedPlayers => participants
      .where((MatchParticipant p) => p.response == ParticipantResponse.accepted)
      .length;

  /// Plazas totales según la modalidad.
  int get requiredPlayers => format.maxPlayers;

  /// `true` si ya están confirmados todos los jugadores.
  bool get isFull => confirmedPlayers >= requiredPlayers;

  /// `true` si el partido sigue activo (ni cancelado ni finalizado).
  bool get isActive =>
      status == MatchStatus.confirmed || status == MatchStatus.awaitingPlayers;

  /// `true` si el usuario indicado tiene una invitación sin responder.
  bool hasPendingInvitationFor(String userId) => participants.any(
    (MatchParticipant p) =>
        p.id == userId && p.response == ParticipantResponse.invited,
  );
}
