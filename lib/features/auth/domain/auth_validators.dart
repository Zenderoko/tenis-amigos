/// Validaciones compartidas por los formularios de autenticación.
abstract final class AuthValidators {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  static String? displayName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Ingresa tu nombre.';
    }
    if (name.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (name.length > 60) {
      return 'El nombre no puede superar los 60 caracteres.';
    }
    return null;
  }

  static String? password(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa una contraseña.';
    }
    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }

  static String? currentPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Ingresa tu contraseña actual.';
    }
    return null;
  }

  static String? newPassword(String? value, String currentPassword) {
    final String? error = password(value);
    if (error != null) {
      return error;
    }
    if (value == currentPassword) {
      return 'La nueva contraseña debe ser distinta de la actual.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return 'Repite tu contraseña.';
    }
    if (value != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
