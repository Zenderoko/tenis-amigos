import '../domain/auth_user.dart';

/// Contrato de acceso a la autenticación.
///
/// Las pantallas y el controlador dependen de esta abstracción, no de
/// Supabase, para poder sustituir la implementación en pruebas.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  Future<AuthUser> signInWithGoogle({required String idToken});

  Future<void> signOut();
}
