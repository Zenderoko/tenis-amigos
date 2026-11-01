import 'auth_user.dart';

/// Tipos de cambio de sesión que la aplicación necesita distinguir.
enum AuthChangeType {
  initial,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  passwordRecovery,
  other,
}

/// Cambio de sesión emitido por el proveedor de autenticación.
class AuthStateChange {
  const AuthStateChange({required this.type, this.user});

  final AuthChangeType type;
  final AuthUser? user;
}
