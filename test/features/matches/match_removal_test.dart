import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/matches/domain/match.dart';

void main() {
  Match buildMatch({
    MatchStatus status = MatchStatus.awaitingPlayers,
    String organizerId = 'org',
    List<MatchParticipant> participants = const <MatchParticipant>[],
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
  const MatchParticipant declined = MatchParticipant(
    id: 'p3',
    name: 'Rechazó',
    response: ParticipantResponse.declined,
  );
  const MatchParticipant withdrawn = MatchParticipant(
    id: 'p4',
    name: 'Retirado',
    response: ParticipantResponse.withdrawn,
  );

  group('Estados nuevos', () {
    test('ParticipantResponse reconoce "removed"', () {
      expect(
        ParticipantResponse.fromValue('removed'),
        ParticipantResponse.removed,
      );
    });

    test('MatchEventType reconoce "removed"', () {
      expect(MatchEventType.fromValue('removed'), MatchEventType.removed);
    });
  });

  group('canRemovePlayer', () {
    test('el organizador puede eliminar invitados y confirmados', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed, invited],
      );

      expect(match.canRemovePlayer('org', 'p1'), isTrue);
      expect(match.canRemovePlayer('org', 'p2'), isTrue);
    });

    test('el organizador no puede eliminarse a sí mismo', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed],
      );

      expect(match.canRemovePlayer('org', 'org'), isFalse);
    });

    test('no se elimina a rechazados ni retirados', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[
          organizer,
          declined,
          withdrawn,
        ],
      );

      expect(match.canRemovePlayer('org', 'p3'), isFalse);
      expect(match.canRemovePlayer('org', 'p4'), isFalse);
    });

    test('un jugador que no organiza no puede eliminar', () {
      final Match match = buildMatch(
        participants: const <MatchParticipant>[organizer, confirmed, invited],
      );

      expect(match.canRemovePlayer('p1', 'p2'), isFalse);
    });

    test('no se puede eliminar si el partido no está activo', () {
      final Match match = buildMatch(
        status: MatchStatus.cancelled,
        participants: const <MatchParticipant>[organizer, confirmed],
      );

      expect(match.canRemovePlayer('org', 'p1'), isFalse);
    });
  });
}
