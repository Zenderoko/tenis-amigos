import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('rechaza un correo vacío', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email(null), isNotNull);
    });

    test('rechaza un correo sin dominio válido', () {
      expect(AuthValidators.email('jugador@'), isNotNull);
      expect(AuthValidators.email('jugador'), isNotNull);
    });

    test('acepta un correo válido y recorta espacios', () {
      expect(AuthValidators.email('  jugador@example.com  '), isNull);
    });
  });

  group('AuthValidators.displayName', () {
    test('rechaza nombres demasiado cortos o largos', () {
      expect(AuthValidators.displayName('A'), isNotNull);
      expect(AuthValidators.displayName('A' * 61), isNotNull);
    });

    test('acepta un nombre normal', () {
      expect(AuthValidators.displayName('Ana'), isNull);
    });
  });

  group('AuthValidators.password', () {
    test('exige al menos 8 caracteres', () {
      expect(AuthValidators.password('1234567'), isNotNull);
      expect(AuthValidators.password('12345678'), isNull);
    });

    test('la confirmación debe coincidir', () {
      expect(AuthValidators.confirmPassword('otra', 'secreta123'), isNotNull);
      expect(
        AuthValidators.confirmPassword('secreta123', 'secreta123'),
        isNull,
      );
    });
  });

  group('AuthValidators.currentPassword', () {
    test('exige la contraseña actual', () {
      expect(AuthValidators.currentPassword(''), isNotNull);
      expect(AuthValidators.currentPassword(null), isNotNull);
      expect(AuthValidators.currentPassword('actual123'), isNull);
    });
  });

  group('AuthValidators.newPassword', () {
    test('exige una contraseña nueva válida y distinta', () {
      expect(AuthValidators.newPassword('', 'actual123'), isNotNull);
      expect(AuthValidators.newPassword('corta', 'actual123'), isNotNull);
      expect(AuthValidators.newPassword('actual123', 'actual123'), isNotNull);
      expect(AuthValidators.newPassword('nueva123', 'actual123'), isNull);
    });
  });
}
