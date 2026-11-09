import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/core/utils/match_time.dart';

void main() {
  group('MatchTime', () {
    test('convierte hora de invierno de Santiago a UTC', () {
      final DateTime utc = MatchTime.toUtc(
        local: DateTime(2026, 7, 15, 19),
        timezone: 'America/Santiago',
      );

      expect(utc, DateTime.utc(2026, 7, 15, 23));
    });

    test('convierte hora de verano de Santiago a UTC', () {
      final DateTime utc = MatchTime.toUtc(
        local: DateTime(2026, 1, 15, 19),
        timezone: 'America/Santiago',
      );

      expect(utc, DateTime.utc(2026, 1, 15, 22));
    });

    test('convierte un instante UTC a la hora local del partido', () {
      final DateTime local = MatchTime.inZone(
        DateTime.utc(2026, 1, 15, 22),
        'America/Santiago',
      );

      expect(local.year, 2026);
      expect(local.month, 1);
      expect(local.day, 15);
      expect(local.hour, 19);
    });

    test('usa Santiago como respaldo para una zona desconocida', () {
      final DateTime local = MatchTime.inZone(
        DateTime.utc(2026, 7, 15, 23),
        'Zona/Inexistente',
      );

      expect(local.hour, 19);
    });
  });
}
