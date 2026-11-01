import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/profile/domain/dominant_hand.dart';
import 'package:tenis_amigos/features/profile/domain/tennis_level.dart';

void main() {
  group('TennisLevel', () {
    test('convierte claves estables', () {
      expect(TennisLevel.fromValue('beginner'), TennisLevel.beginner);
      expect(TennisLevel.fromValue('competitive'), TennisLevel.competitive);
    });

    test('convierte etiquetas antiguas en español', () {
      expect(TennisLevel.fromValue('Principiante'), TennisLevel.beginner);
      expect(TennisLevel.fromValue('Intermedio'), TennisLevel.intermediate);
      expect(TennisLevel.fromValue('Avanzado'), TennisLevel.advanced);
      expect(TennisLevel.fromValue('Competitivo'), TennisLevel.competitive);
    });

    test('devuelve null para valores vacíos o desconocidos', () {
      expect(TennisLevel.fromValue(null), isNull);
      expect(TennisLevel.fromValue('  '), isNull);
      expect(TennisLevel.fromValue('profesional'), isNull);
    });
  });

  group('DominantHand', () {
    test('convierte claves y etiquetas', () {
      expect(DominantHand.fromValue('right'), DominantHand.right);
      expect(DominantHand.fromValue('Diestro'), DominantHand.right);
      expect(DominantHand.fromValue('left'), DominantHand.left);
      expect(DominantHand.fromValue('Zurdo'), DominantHand.left);
    });

    test('devuelve null para valores desconocidos', () {
      expect(DominantHand.fromValue('ambidiestro'), isNull);
      expect(DominantHand.fromValue(null), isNull);
    });
  });
}
