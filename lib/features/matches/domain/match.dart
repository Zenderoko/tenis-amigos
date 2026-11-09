/// Enumeraciones y modelos de partidos.
library;

import '../../profile/domain/tennis_level.dart';

/// Zona horaria usada por el MVP para guardar y mostrar los partidos.
const String kDefaultMatchTimezone = 'America/Santiago';

/// Modalidad del partido y número de jugadores que admite.
enum MatchFormat {
  singles('Singles', 2, 'singles'),
  doubles('Dobles', 4, 'doubles');

  const MatchFormat(this.label, this.maxPlayers, this.dbValue);

  /// Texto visible en español.
  final String label;

  /// Número total de jugadores que admite la modalidad.
  final int maxPlayers;

  /// Valor almacenado en PostgreSQL.
  final String dbValue;

  static MatchFormat fromValue(String? value) {
    return values.firstWhere(
      (MatchFormat format) => format.dbValue == value,
      orElse: () => MatchFormat.singles,
    );
  }
}

/// Estado de un partido.
///
/// - [awaitingPlayers]: falta confirmar jugadores.
/// - [confirmed]: cupo completo confirmado.
/// - [cancelled]: el organizador lo canceló.
/// - [completed]: el partido ya se jugó.
enum MatchStatus {
  awaitingPlayers('Faltan jugadores', 'awaiting_players'),
  confirmed('Confirmado', 'confirmed'),
  cancelled('Cancelado', 'cancelled'),
  completed('Finalizado', 'completed');

  const MatchStatus(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MatchStatus fromValue(String? value) {
    return values.firstWhere(
      (MatchStatus status) => status.dbValue == value,
      orElse: () => MatchStatus.awaitingPlayers,
    );
  }
}

/// Respuesta de un jugador a su invitación.
enum ParticipantResponse {
  invited('Invitado', 'invited'),
  accepted('Confirmado', 'accepted'),
  declined('Rechazado', 'declined'),
  withdrawn('Retirado', 'withdrawn');

  const ParticipantResponse(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static ParticipantResponse fromValue(String? value) {
    return values.firstWhere(
      (ParticipantResponse response) => response.dbValue == value,
      orElse: () => ParticipantResponse.invited,
    );
  }
}

/// Tipo de evento del historial de un partido.
enum MatchEventType {
  created('Partido creado', 'created'),
  invited('Invitación enviada', 'invited'),
  responded('Respuesta recibida', 'responded'),
  proposed('Reprogramación propuesta', 'proposed'),
  rescheduled('Horario actualizado', 'rescheduled'),
  cancelled('Partido cancelado', 'cancelled'),
  completed('Partido finalizado', 'completed');

  const MatchEventType(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MatchEventType fromValue(String? value) {
    return values.firstWhere(
      (MatchEventType type) => type.dbValue == value,
      orElse: () => MatchEventType.created,
    );
  }
}

/// Un jugador dentro de un partido.
class MatchParticipant {
  const MatchParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.tennisLevel,
    this.isOrganizer = false,
    this.response = ParticipantResponse.invited,
  });

  /// Identificador del usuario en Supabase Auth.
  final String id;
  final String name;
  final String? avatarUrl;
  final TennisLevel? tennisLevel;
  final bool isOrganizer;
  final ParticipantResponse response;

  MatchParticipant copyWith({
    ParticipantResponse? response,
    bool? isOrganizer,
  }) {
    return MatchParticipant(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      tennisLevel: tennisLevel,
      isOrganizer: isOrganizer ?? this.isOrganizer,
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
    this.organizerId = '',
    this.timezone = kDefaultMatchTimezone,
    this.locationDetails,
    this.events = const <MatchEvent>[],
    this.version = 1,
  });

  final String id;

  /// Usuario que organizó el partido.
  final String organizerId;

  final MatchFormat format;

  /// Inicio del partido en UTC.
  final DateTime startsAt;

  /// Zona horaria IANA del partido.
  final String timezone;

  final int durationMinutes;
  final String locationName;
  final String? locationDetails;
  final MatchStatus status;
  final List<MatchParticipant> participants;
  final List<MatchEvent> events;

  /// Versión para detectar cambios concurrentes.
  final int version;

  /// Jugadores que ya confirmaron su asistencia.
  int get confirmedPlayers => participants
      .where((MatchParticipant p) => p.response == ParticipantResponse.accepted)
      .length;

  /// Jugadores que ocupan una plaza activa (invitados o aceptados).
  int get activePlayers => participants
      .where(
        (MatchParticipant p) =>
            p.response == ParticipantResponse.invited ||
            p.response == ParticipantResponse.accepted,
      )
      .length;

  /// Invitaciones que todavía esperan respuesta.
  int get pendingPlayers => participants
      .where((MatchParticipant p) => p.response == ParticipantResponse.invited)
      .length;

  /// Plazas totales según la modalidad.
  int get requiredPlayers => format.maxPlayers;

  /// Plazas activas que todavía se pueden cubrir.
  int get availableSlots {
    final int slots = requiredPlayers - activePlayers;
    return slots < 0 ? 0 : slots;
  }

  /// `true` si ya están confirmados todos los jugadores.
  bool get isFull => confirmedPlayers >= requiredPlayers;

  /// `true` si el partido sigue activo (ni cancelado ni finalizado).
  bool get isActive =>
      status == MatchStatus.confirmed || status == MatchStatus.awaitingPlayers;

  /// Organizador del partido, si está presente en la lista de jugadores.
  MatchParticipant? get organizer {
    for (final MatchParticipant participant in participants) {
      if (participant.isOrganizer) return participant;
    }
    return null;
  }

  MatchParticipant? participantFor(String userId) {
    for (final MatchParticipant participant in participants) {
      if (participant.id == userId) return participant;
    }
    return null;
  }

  ParticipantResponse? responseFor(String userId) =>
      participantFor(userId)?.response;

  bool isOrganizer(String userId) =>
      organizerId == userId || participantFor(userId)?.isOrganizer == true;

  bool isParticipant(String userId) => participantFor(userId) != null;

  /// `true` si el usuario indicado tiene una invitación sin responder.
  bool hasPendingInvitationFor(String userId) =>
      responseFor(userId) == ParticipantResponse.invited;

  /// `true` si el usuario puede aceptar o rechazar la invitación.
  bool canRespond(String userId) => isActive && hasPendingInvitationFor(userId);
}
