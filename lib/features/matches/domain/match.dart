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
  withdrawn('Retirado', 'withdrawn'),
  removed('Eliminado', 'removed');

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
  rescheduleRejected('Reprogramación rechazada', 'reschedule_rejected'),
  withdrawn('Jugador retirado', 'withdrawn'),
  removed('Jugador eliminado', 'removed'),
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

/// Estado de una propuesta de reprogramación.
enum MatchProposalStatus {
  pending('Pendiente', 'pending'),
  accepted('Aceptada', 'accepted'),
  rejected('Rechazada', 'rejected'),
  superseded('Reemplazada', 'superseded');

  const MatchProposalStatus(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MatchProposalStatus fromValue(String? value) {
    return values.firstWhere(
      (MatchProposalStatus status) => status.dbValue == value,
      orElse: () => MatchProposalStatus.pending,
    );
  }
}

/// Voto de un jugador sobre una propuesta de reprogramación.
class MatchProposalVote {
  const MatchProposalVote({required this.userId, required this.accepted});

  final String userId;
  final bool accepted;
}

/// Propuesta de reprogramación de un partido.
class MatchProposal {
  const MatchProposal({
    required this.id,
    required this.proposedBy,
    required this.proposedStartsAt,
    required this.timezone,
    required this.status,
    required this.createdAt,
    this.votes = const <MatchProposalVote>[],
  });

  final String id;

  /// Usuario que propuso el cambio.
  final String proposedBy;

  /// Nuevo inicio propuesto, en UTC.
  final DateTime proposedStartsAt;

  /// Zona horaria IANA de la propuesta.
  final String timezone;

  final MatchProposalStatus status;

  /// Momento en que se creó la propuesta (hora local del dispositivo).
  final DateTime createdAt;

  final List<MatchProposalVote> votes;

  /// `true` si el usuario indicado propuso el cambio.
  bool isProposer(String userId) => proposedBy == userId;

  /// Voto del usuario indicado, si ya respondió.
  MatchProposalVote? voteFor(String userId) {
    for (final MatchProposalVote vote in votes) {
      if (vote.userId == userId) return vote;
    }
    return null;
  }

  bool hasVoted(String userId) => voteFor(userId) != null;

  int get acceptedVotes =>
      votes.where((MatchProposalVote vote) => vote.accepted).length;

  int get rejectedVotes =>
      votes.where((MatchProposalVote vote) => !vote.accepted).length;
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
    this.pendingProposal,
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

  /// Propuesta de reprogramación pendiente de aprobación, si existe.
  final MatchProposal? pendingProposal;

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

  /// `true` si el usuario puede cancelar el partido (organizador y activo).
  bool canCancel(String userId) => isActive && isOrganizer(userId);

  /// `true` si el usuario puede retirarse (jugador aceptado que no organiza).
  bool canWithdraw(String userId) =>
      isActive &&
      !isOrganizer(userId) &&
      responseFor(userId) == ParticipantResponse.accepted;

  /// `true` si el organizador indicado puede eliminar a [targetId] del partido.
  bool canRemovePlayer(String organizerId, String targetId) {
    if (!isActive || !isOrganizer(organizerId)) return false;
    if (targetId == organizerId) return false;
    final MatchParticipant? target = participantFor(targetId);
    if (target == null) return false;
    return target.response == ParticipantResponse.invited ||
        target.response == ParticipantResponse.accepted;
  }

  /// `true` si el usuario puede proponer una reprogramación.
  bool canProposeReschedule(String userId) =>
      isActive && isOrganizer(userId) && pendingProposal == null;

  /// `true` si el usuario puede retirar la propuesta pendiente.
  bool canCancelProposal(String userId) =>
      isActive && isOrganizer(userId) && pendingProposal != null;

  /// `true` si el usuario puede aceptar o rechazar la propuesta pendiente.
  bool canRespondToProposal(String userId) {
    final MatchProposal? proposal = pendingProposal;
    if (proposal == null || !isActive) return false;
    if (proposal.isProposer(userId)) return false;
    if (responseFor(userId) != ParticipantResponse.accepted) return false;
    return !proposal.hasVoted(userId);
  }

  /// Jugadores aceptados que deben aprobar la propuesta pendiente.
  int proposalVotersRequired(String organizerId) => participants
      .where(
        (MatchParticipant participant) =>
            participant.response == ParticipantResponse.accepted &&
            participant.id != organizerId,
      )
      .length;
}
