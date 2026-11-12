import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/matches/domain/match.dart';

void main() {
  Match buildMatch({
    MatchStatus status = MatchStatus.awaitingPlayers,
    String organizerId = 'org',
    List<MatchParticipant> participants = const <MatchParticipant>[],
    MatchProposal? proposal,
  }) {
    return Match(
      id: 'm1',
      organizerId: organizerId,
      format: MatchFormat.doubles,
      startsAt: DateTime.utc(2030, 1, 1, 22),
      durationMinutes: 90,
      locationName: 'Cancha de prueba',
      status: status,
      participants: participants,
      pendingProposal: proposal,
    );
  }

  const MatchParticipant organizer = MatchParticipant(
    id: 'org',
    name: 'Organizador',
    isOrganizer: true,
    response: ParticipantResponse.accepted,
  );
  const MatchParticipant confirmed = MatchParticipant(
    id: 'p1',
    name: 'Confirmado',
    response: ParticipantResponse.accepted,
  );
  const MatchParticipant invited = MatchParticipant(
    id: 'p2',
    name: 'Invitado',
    response: ParticipantResponse.invited,
  );

  MatchProposal buildProposal({
    String proposedBy = 'org',
    MatchProposalStatus status = MatchProposalStatus.pending,
    List<MatchProposalVote> votes = const <MatchProposalVote>[],
  }) {
    return MatchProposal(
      id: 'prop1',
      proposedBy: proposedBy,
      proposedStartsAt: DateTime.utc(2030, 1, 2, 22),
      timezone: 'America/Santiago',
      status: status,
      createdAt: DateTime(2029, 12, 1),
      votes: votes,
    );
  }

  group('MatchEventType', () {
    test('reconoce los eventos de la Etapa 5', () {
      expect(
        MatchEventType.fromValue('withdrawn'),
        MatchEventType.withdrawn,
      );
      expect(
        MatchEventType.fromValue('reschedule_rejected'),
        MatchEventType.rescheduleRejected,
      );
    });
  });

  group('MatchProposalStatus', () {
    test('convierte los valores de Supabase', () {
      expect(
        MatchProposalStatus.fromValue('accepted'),
        MatchProposalStatus.accepted,
      );
      expect(
        MatchProposalStatus.fromValue('superseded'),
        MatchProposalStatus.superseded,
      );
      expect(
        MatchProposalStatus.fromValue('desconocido'),
        MatchProposalStatus.pending,
      );
    });
  });

  group('MatchProposal', () {
    test('cuenta votos, detecta al proponente y al votante', () {
      final MatchProposal proposal = buildProposal(
        votes: const <MatchProposalVote>[
          MatchProposalVote(userId: 'p1', accepted: true),
          MatchProposalVote(userId: 'p2', accepted: false),
        ],
      );

      expect(proposal.isProposer('org'), isTrue);
      expect(proposal.isProposer('p1'), isFalse);
      expect(proposal.acceptedVotes, 1);
      expect(proposal.rejectedVotes, 1);
      expect(proposal.hasVoted('p1'), isTrue);
      expect(proposal.hasVoted('p3'), isFalse);
      expect(proposal.voteFor('p2')?.accepted, isFalse);
    });
  });

  group('Acciones del partido', () {
    test('el organizador puede cancelar y proponer mientras está activo', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed],
      );

      expect(match.canCancel('org'), isTrue);
      expect(match.canProposeReschedule('org'), isTrue);
      expect(match.canWithdraw('org'), isFalse);
      expect(match.canCancel('p1'), isFalse);
    });

    test('no se puede cancelar ni proponer si está cancelado', () {
      final Match match = buildMatch(
        status: MatchStatus.cancelled,
        participants: const <MatchParticipant>[organizer, confirmed],
      );

      expect(match.canCancel('org'), isFalse);
      expect(match.canProposeReschedule('org'), isFalse);
      expect(match.canWithdraw('p1'), isFalse);
    });

    test('un jugador aceptado puede retirarse, no así uno invitado', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed, invited],
      );

      expect(match.canWithdraw('p1'), isTrue);
      expect(match.canWithdraw('p2'), isFalse);
    });

    test('no se puede proponer si ya hay una propuesta pendiente', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed],
        proposal: buildProposal(),
      );

      expect(match.canProposeReschedule('org'), isFalse);
      expect(match.canCancelProposal('org'), isTrue);
      expect(match.pendingProposal, isNotNull);
    });

    test('los jugadores confirmados pueden responder y el proponente no', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed, invited],
        proposal: buildProposal(),
      );

      expect(match.canRespondToProposal('p1'), isTrue);
      expect(match.canRespondToProposal('org'), isFalse);
      expect(match.canRespondToProposal('p2'), isFalse);
    });

    test('un jugador que ya votó no vuelve a responder', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed],
        proposal: buildProposal(
          votes: const <MatchProposalVote>[
            MatchProposalVote(userId: 'p1', accepted: true),
          ],
        ),
      );

      expect(match.canRespondToProposal('p1'), isFalse);
    });

    test('proposalVotersRequired excluye al organizador', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed, invited],
      );

      expect(match.proposalVotersRequired('org'), 1);
    });
  });
}
