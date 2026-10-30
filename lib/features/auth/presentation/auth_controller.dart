import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../profile/data/profile_providers.dart';
import '../../profile/data/supabase_profile_repository.dart';
import '../data/auth_providers.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import '../domain/auth_user.dart';

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
    return ref.watch(authRepositoryProvider).currentUser;
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
