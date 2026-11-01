import '../domain/auth_state_change.dart';
import '../domain/auth_user.dart';
import '../domain/sign_up_result.dart';

/// Contrato de acceso a la autenticación.
///
/// Las pantallas y el controlador dependen de esta abstracción, no de
/// Supabase, para poder sustituir la implementación en pruebas.
abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Cambios de sesión (incluye la recuperación de contraseña por enlace).
  Stream<AuthStateChange> get authStateChanges;

  Future<AuthUser> signInWithGoogle({required String idToken});

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> resendConfirmationEmail({required String email});

  Future<AuthUser> updatePassword({required String newPassword});

  Future<void> signOut();
}
