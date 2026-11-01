import 'auth_user.dart';

/// Resultado de un registro con correo y contraseña.
///
/// Cuando Supabase exige confirmar el correo, devuelve un usuario pero no una
/// sesión. En ese caso [user] es `null` y [requiresEmailConfirmation] es `true`.
class SignUpResult {
  const SignUpResult._({
    required this.user,
    required this.requiresEmailConfirmation,
  });

  const SignUpResult.authenticated(AuthUser user)
    : this._(user: user, requiresEmailConfirmation: false);

  const SignUpResult.confirmationRequired()
    : this._(user: null, requiresEmailConfirmation: true);

  final AuthUser? user;
  final bool requiresEmailConfirmation;

  bool get isAuthenticated => user != null;
}
