import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import '../domain/auth_state_change.dart';
import '../domain/auth_user.dart';
import '../domain/sign_up_result.dart';

/// Estado global de autenticación.
///
/// `AsyncData(null)` significa que no hay sesión y `AsyncData(user)` que hay un
/// usuario autenticado. Mientras se inicia o cierra sesión el estado es
/// `AsyncLoading`.
final AsyncNotifierProvider<AuthController, AuthUser?> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final AuthRepository repository = ref.watch(authRepositoryProvider);

    // Mantiene el estado sincronizado cuando Supabase restaura una sesión,
    // confirma un correo o procesa un enlace de recuperación.
    final subscription = repository.authStateChanges.listen((
      AuthStateChange change,
    ) {
      if (change.type == AuthChangeType.initial) {
        return;
      }
      state = AsyncData<AuthUser?>(change.user);
    });
    ref.onDispose(subscription.cancel);

    return repository.currentUser;
  }

  /// Registra o inicia sesión con Google y guarda el perfil en Supabase.
  ///
  /// El mismo flujo sirve para registro y para inicio de sesión: Supabase crea
  /// el usuario la primera vez y lo recupera en las siguientes.
  Future<AuthUser> signInWithGoogle() async {
    state = const AsyncLoading<AuthUser?>();

    try {
      final GoogleAuthService google = ref.read(googleAuthServiceProvider);
      final AuthRepository auth = ref.read(authRepositoryProvider);

      final String idToken = await google.obtainIdToken();
      final AuthUser user = await auth.signInWithGoogle(idToken: idToken);
      await _ensureProfile(user);

      state = AsyncData<AuthUser?>(user);
      return user;
    } on AppFailure catch (error, stackTrace) {
      state = AsyncError<AuthUser?>(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      const AppFailure failure = AppFailure(
        'No pudimos iniciar sesión. Intenta de nuevo.',
        code: 'unexpected_sign_in_error',
      );
      state = AsyncError<AuthUser?>(failure, stackTrace);
      throw failure;
    }
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<AuthUser?>();

    try {
      final AuthRepository auth = ref.read(authRepositoryProvider);
      final AuthUser user = await auth.signInWithEmail(
        email: email,
        password: password,
      );
      await _ensureProfile(user);

      state = AsyncData<AuthUser?>(user);
      return user;
    } on AppFailure catch (error, stackTrace) {
      state = AsyncError<AuthUser?>(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      const AppFailure failure = AppFailure(
        'No pudimos iniciar sesión. Intenta de nuevo.',
        code: 'unexpected_sign_in_error',
      );
      state = AsyncError<AuthUser?>(failure, stackTrace);
      throw failure;
    }
  }

  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading<AuthUser?>();

    try {
      final AuthRepository auth = ref.read(authRepositoryProvider);
      final SignUpResult result = await auth.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      final AuthUser? user = result.user;
      if (user == null) {
        state = const AsyncData<AuthUser?>(null);
        return result;
      }

      await _ensureProfile(user);
      state = AsyncData<AuthUser?>(user);
      return result;
    } on AppFailure catch (error, stackTrace) {
      state = AsyncError<AuthUser?>(error, stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      const AppFailure failure = AppFailure(
        'No pudimos crear tu cuenta. Intenta de nuevo.',
        code: 'unexpected_sign_up_error',
      );
      state = AsyncError<AuthUser?>(failure, stackTrace);
      throw failure;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(email: email);
  }

  Future<void> resendConfirmationEmail({required String email}) {
    return ref
        .read(authRepositoryProvider)
        .resendConfirmationEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final AuthUser? user = auth.currentUser;
    if (user == null) {
      throw const AppFailure(
        'Tu sesión expiró. Inicia sesión de nuevo.',
        code: 'no_session',
      );
    }

    try {
      await auth.signInWithEmail(email: user.email, password: currentPassword);
    } on AppFailure catch (error) {
      if (error.code == 'invalid_credentials') {
        throw const AppFailure(
          'La contraseña actual no es correcta.',
          code: 'invalid_current_password',
        );
      }
      rethrow;
    }

    final AuthUser updated = await auth.updatePassword(
      newPassword: newPassword,
    );
    state = AsyncData<AuthUser?>(updated);
  }

  Future<AuthUser> updatePassword({required String newPassword}) async {
    final AsyncValue<AuthUser?> previous = state;
    try {
      final AuthUser user = await ref
          .read(authRepositoryProvider)
          .updatePassword(newPassword: newPassword);
      state = AsyncData<AuthUser?>(user);
      return user;
    } on AppFailure {
      // Un fallo al guardar la contraseña no invalida la sesión de
      // recuperación; la pantalla muestra el error y conserva el formulario.
      state = previous;
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading<AuthUser?>();

    try {
      await ref.read(googleAuthServiceProvider).signOut();
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData<AuthUser?>(null);
    } on AppFailure catch (error, stackTrace) {
      state = AsyncError<AuthUser?>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _ensureProfile(AuthUser user) async {
    final ProfileRepository repository = ref.read(profileRepositoryProvider);

    try {
      await repository.ensureProfile(
        userId: user.id,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw const AppFailure(
        'Tu cuenta se creó, pero no pudimos guardar tu perfil. Intenta de nuevo.',
        code: 'profile_save_error',
      );
    }
  }
}
