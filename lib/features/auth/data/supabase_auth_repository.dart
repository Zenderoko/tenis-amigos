import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/constants/auth_links.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/auth_state_change.dart';
import '../domain/auth_user.dart';
import '../domain/sign_up_result.dart';
import 'auth_repository.dart';

/// Implementación de autenticación basada en Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository([this._client]);

  static const AppFailure _emailAlreadyRegisteredFailure = AppFailure(
    'Ya existe una cuenta con ese correo. Inicia sesión o recupera tu '
    'contraseña.',
    code: 'email_already_registered',
  );

  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    final SupabaseClient? client = _client;
    if (client != null) {
      return client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw const AppFailure(
        'Supabase no está configurado. Revisa SUPABASE_URL y '
        'SUPABASE_PUBLISHABLE_KEY en .env.',
        code: 'supabase_not_configured',
      );
    }
  }

  @override
  AuthUser? get currentUser {
    try {
      final User? user = _supabase.auth.currentUser;
      return user == null ? null : _mapUser(user);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AuthStateChange> get authStateChanges {
    final SupabaseClient client;
    try {
      client = _supabase;
    } catch (_) {
      return const Stream<AuthStateChange>.empty();
    }

    return client.auth.onAuthStateChange.map((AuthState state) {
      final User? user = state.session?.user;
      return AuthStateChange(
        type: _mapEvent(state.event),
        user: user == null ? null : _mapUser(user),
      );
    });
  }

  @override
  Future<AuthUser> signInWithGoogle({required String idToken}) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return _requireUser(
        response.user,
        'Supabase no devolvió el usuario autenticado.',
      );
    } on AppFailure {
      rethrow;
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage:
            'No pudimos iniciar sesión con Google. Intenta de '
            'nuevo.',
        fallbackCode: 'google_sign_in_error',
      );
    } catch (error) {
      debugPrint('Supabase Google sign in error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_sign_in_error',
      );
    }
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(
        response.user,
        'Supabase no devolvió el usuario autenticado.',
      );
    } on AppFailure {
      rethrow;
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage: 'No pudimos iniciar sesión. Intenta de nuevo.',
        fallbackCode: 'email_sign_in_error',
      );
    } catch (error) {
      debugPrint('Supabase email sign in error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_sign_in_error',
      );
    }
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'full_name': displayName.trim()},
        emailRedirectTo: AuthLinks.redirectUrl,
      );

      final User? user = response.user;
      if (user == null) {
        throw const AppFailure(
          'Supabase no devolvió el usuario creado.',
          code: 'missing_supabase_user',
        );
      }

      if (user.identities?.isEmpty ?? false) {
        throw _emailAlreadyRegisteredFailure;
      }

      if (response.session == null) {
        return const SignUpResult.confirmationRequired();
      }
      return SignUpResult.authenticated(_mapUser(user));
    } on AppFailure {
      rethrow;
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage: 'No pudimos crear tu cuenta. Intenta de nuevo.',
        fallbackCode: 'email_sign_up_error',
      );
    } catch (error) {
      debugPrint('Supabase sign up error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_sign_up_error',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AuthLinks.redirectUrl,
      );
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage:
            'No pudimos enviar el correo de recuperación. Intenta '
            'de nuevo.',
        fallbackCode: 'password_reset_error',
      );
    } catch (error) {
      debugPrint('Supabase password reset error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_password_reset_error',
      );
    }
  }

  @override
  Future<void> resendConfirmationEmail({required String email}) async {
    try {
      await _supabase.auth.resend(
        email: email.trim(),
        type: OtpType.signup,
        emailRedirectTo: AuthLinks.redirectUrl,
      );
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage:
            'No pudimos reenviar el correo de confirmación. '
            'Intenta de nuevo.',
        fallbackCode: 'confirmation_resend_error',
      );
    } catch (error) {
      debugPrint('Supabase confirmation resend error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_confirmation_resend_error',
      );
    }
  }

  @override
  Future<AuthUser> updatePassword({required String newPassword}) async {
    try {
      final UserResponse response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return _requireUser(
        response.user,
        'Supabase no devolvió el usuario actualizado.',
      );
    } on AppFailure {
      rethrow;
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage:
            'No pudimos actualizar tu contraseña. Intenta de '
            'nuevo.',
        fallbackCode: 'password_update_error',
      );
    } catch (error) {
      debugPrint('Supabase password update error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de '
        'nuevo.',
        code: 'supabase_password_update_error',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (error) {
      throw _failureFor(
        error,
        fallbackMessage: 'No pudimos cerrar la sesión en el servidor.',
        fallbackCode: 'sign_out_error',
      );
    }
  }

  AuthUser _requireUser(User? user, String message) {
    if (user == null) {
      throw AppFailure(message, code: 'missing_supabase_user');
    }
    return _mapUser(user);
  }

  AuthUser _mapUser(User user) {
    final Map<String, dynamic> metadata =
        user.userMetadata ?? <String, dynamic>{};
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: _firstNonEmpty(<Object?>[
        metadata['full_name'],
        metadata['name'],
      ]),
      photoUrl: _firstNonEmpty(<Object?>[
        metadata['avatar_url'],
        metadata['picture'],
      ]),
    );
  }

  AuthChangeType _mapEvent(AuthChangeEvent event) {
    return switch (event) {
      AuthChangeEvent.initialSession => AuthChangeType.initial,
      AuthChangeEvent.signedIn => AuthChangeType.signedIn,
      AuthChangeEvent.signedOut => AuthChangeType.signedOut,
      AuthChangeEvent.tokenRefreshed => AuthChangeType.tokenRefreshed,
      AuthChangeEvent.userUpdated => AuthChangeType.userUpdated,
      AuthChangeEvent.passwordRecovery => AuthChangeType.passwordRecovery,
      _ => AuthChangeType.other,
    };
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final Object? value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  AppFailure _failureFor(
    AuthException error, {
    required String fallbackMessage,
    required String fallbackCode,
  }) {
    debugPrint('Supabase AuthException: ${error.code} ${error.message}');

    switch (error.code) {
      case 'invalid_credentials':
        return const AppFailure(
          'Correo o contraseña incorrectos.',
          code: 'invalid_credentials',
        );
      case 'email_not_confirmed':
        return const AppFailure(
          'Tu correo aún no está confirmado. Revisa tu bandeja de entrada.',
          code: 'email_not_confirmed',
        );
      case 'user_already_exists':
      case 'email_exists':
        return _emailAlreadyRegisteredFailure;
      case 'weak_password':
        return const AppFailure(
          'La contraseña es demasiado débil. Usa al menos 8 caracteres.',
          code: 'weak_password',
        );
      case 'same_password':
        return const AppFailure(
          'La nueva contraseña debe ser distinta de la actual.',
          code: 'same_password',
        );
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return const AppFailure(
          'Hiciste demasiados intentos. Espera unos minutos e inténtalo de '
          'nuevo.',
          code: 'rate_limited',
        );
      case 'signup_disabled':
        return const AppFailure(
          'El registro con correo está deshabilitado en Supabase.',
          code: 'signup_disabled',
        );
      case 'email_provider_disabled':
        return const AppFailure(
          'El inicio de sesión con correo está deshabilitado en Supabase.',
          code: 'email_provider_disabled',
        );
      case 'otp_expired':
        return const AppFailure(
          'El enlace expiró. Solicita uno nuevo.',
          code: 'otp_expired',
        );
      case 'session_not_found':
        return const AppFailure(
          'Tu sesión expiró. Solicita un nuevo enlace de recuperación.',
          code: 'session_not_found',
        );
    }

    final String message = error.message.toLowerCase();
    if (message.contains('provider') && message.contains('not enabled')) {
      return const AppFailure(
        'El proveedor de Google no está habilitado en Supabase.',
        code: 'provider_not_enabled',
      );
    }
    if (message.contains('invalid') && message.contains('token')) {
      return const AppFailure(
        'El token de Google no es válido. Revisa que el Web Client ID '
        'coincida con el configurado en Supabase.',
        code: 'invalid_token',
      );
    }
    if (message.contains('email not confirmed')) {
      return const AppFailure(
        'Tu correo aún no está confirmado. Revisa tu bandeja de entrada.',
        code: 'email_not_confirmed',
      );
    }
    if (message.contains('invalid login credentials')) {
      return const AppFailure(
        'Correo o contraseña incorrectos.',
        code: 'invalid_credentials',
      );
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return _emailAlreadyRegisteredFailure;
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests')) {
      return const AppFailure(
        'Hiciste demasiados intentos. Espera unos minutos e inténtalo de '
        'nuevo.',
        code: 'rate_limited',
      );
    }

    return AppFailure(fallbackMessage, code: fallbackCode);
  }
}
