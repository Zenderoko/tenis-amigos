import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/app_failure.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

/// Implementación de autenticación basada en Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository([this._client]);

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
  Future<AuthUser> signInWithGoogle({required String idToken}) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final User? user = response.user;
      if (user == null) {
        throw const AppFailure(
          'Supabase no devolvió el usuario autenticado.',
          code: 'missing_supabase_user',
        );
      }
      return _mapUser(user);
    } on AppFailure {
      rethrow;
    } on AuthException catch (error) {
      debugPrint('Supabase AuthException: ${error.code} ${error.message}');
      throw AppFailure(_messageForAuthException(error), code: error.code);
    } catch (error) {
      debugPrint('Supabase sign in error: $error');
      throw const AppFailure(
        'No pudimos conectar con Supabase. Revisa tu conexión e intenta de nuevo.',
        code: 'supabase_sign_in_error',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (error) {
      debugPrint('Supabase sign out error: ${error.code} ${error.message}');
      throw AppFailure(
        'No pudimos cerrar la sesión en el servidor.',
        code: error.code,
      );
    }
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

  String? _firstNonEmpty(List<Object?> values) {
    for (final Object? value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _messageForAuthException(AuthException error) {
    final String message = error.message.toLowerCase();
    if (message.contains('provider') && message.contains('not enabled')) {
      return 'El proveedor de Google no está habilitado en Supabase.';
    }
    if (message.contains('invalid') && message.contains('token')) {
      return 'El token de Google no es válido. Revisa que el Web Client ID '
          'coincida con el configurado en Supabase.';
    }
    return 'No pudimos iniciar sesión con Google. Intenta de nuevo.';
  }
}
