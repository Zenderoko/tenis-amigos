import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tenis_amigos/core/utils/date_formatters.dart';
import 'package:tenis_amigos/core/utils/avatar_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('AppDateFormatters', () {
    test('formatea una hora en 24h', () {
      expect(AppDateFormatters.time(DateTime(2026, 5, 5, 19, 30)), '19:30');
    });

    test('calcula el rango horario sumando la duración', () {
      final String range = AppDateFormatters.timeRange(
        DateTime(2026, 5, 5, 19, 30),
        90,
      );
      expect(range, '19:30 – 21:00');
    });

    test('capitalize pone en mayúscula solo la primera letra', () {
      expect(AppDateFormatters.capitalize('lunes'), 'Lunes');
      expect(AppDateFormatters.capitalize(''), '');
    });

    test('fullDate está en español', () {
      final String formatted = AppDateFormatters.fullDate(
        DateTime(2026, 5, 5),
      );
      expect(formatted.contains('mayo'), isTrue);
      expect(formatted.contains('2026'), isTrue);
    });
  });

  group('AvatarUtils', () {
    test('usa dos iniciales para nombre y apellido', () {
      expect(AvatarUtils.initialsFor('Camila Rojas'), 'CR');
    });

    test('usa una inicial cuando hay un solo nombre', () {
      expect(AvatarUtils.initialsFor('Matías'), 'M');
    });

    test('devuelve "?" para un nombre vacío', () {
      expect(AvatarUtils.initialsFor('   '), '?');
    });
  });
}
