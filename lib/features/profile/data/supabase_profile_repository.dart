import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/user_profile.dart';

/// Contrato de acceso al perfil del usuario.
abstract interface class ProfileRepository {
  /// Recupera el perfil o lo crea si es la primera vez que inicia sesión.
  Future<UserProfile> ensureProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
  });

  Future<UserProfile> fetchProfile({
    required String userId,
    required String email,
  });
}

/// Implementación del perfil respaldada por Supabase.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository([this._client]);

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
        'Supabase no está configurado. Revisa el archivo .env.',
        code: 'supabase_not_configured',
      );
    }
  }

  @override
  Future<UserProfile> ensureProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final Map<String, dynamic>? existing = await _findProfile(userId);
    if (existing != null) {
      return _maybeSyncGoogleData(
        existing,
        userId: userId,
        email: email,
        photoUrl: photoUrl,
      );
    }

    final String name = _displayName(displayName, email);
    try {
      final Map<String, dynamic> inserted = await _supabase
          .from('profiles')
          .insert(<String, dynamic>{
            'id': userId,
            'display_name': name,
            'avatar_url': _clean(photoUrl),
          })
          .select()
          .single();
      return UserProfile.fromMap(inserted, email: email);
    } on PostgrestException catch (error) {
      // Si otra petición concurrente ya creó el perfil, lo reutilizamos.
      if (error.code == '23505') {
        final Map<String, dynamic>? profile = await _findProfile(userId);
        if (profile != null) {
          return UserProfile.fromMap(profile, email: email);
        }
      }
      debugPrint('Profile insert error: ${error.code} ${error.message}');
      throw AppFailure(_messageForPostgrest(error), code: error.code);
    }
  }

  @override
  Future<UserProfile> fetchProfile({
    required String userId,
    required String email,
  }) async {
    final Map<String, dynamic>? data = await _findProfile(userId);
    if (data == null) {
      return ensureProfile(userId: userId, email: email);
    }
    return UserProfile.fromMap(data, email: email);
  }

  Future<Map<String, dynamic>?> _findProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } on PostgrestException catch (error) {
      debugPrint('Profile select error: ${error.code} ${error.message}');
      throw AppFailure(_messageForPostgrest(error), code: error.code);
    }
  }

  /// Completa el avatar del perfil con la foto de Google la primera vez.
  ///
  /// No sobrescribe datos que el usuario haya editado manualmente.
  Future<UserProfile> _maybeSyncGoogleData(
    Map<String, dynamic> profile, {
    required String userId,
    required String email,
    String? photoUrl,
  }) async {
    final String? currentAvatar = _clean(profile['avatar_url'] as String?);
    final String? googleAvatar = _clean(photoUrl);

    if (currentAvatar == null && googleAvatar != null) {
      try {
        final Map<String, dynamic> updated = await _supabase
            .from('profiles')
            .update(<String, dynamic>{'avatar_url': googleAvatar})
            .eq('id', userId)
            .select()
            .single();
        return UserProfile.fromMap(updated, email: email);
      } on PostgrestException catch (error) {
        debugPrint('Profile update error: ${error.code} ${error.message}');
        // No bloquea el inicio de sesión si solo falla la sincronización.
      }
    }

    return UserProfile.fromMap(profile, email: email);
  }

  String _displayName(String? displayName, String email) {
    final String? name = _clean(displayName);
    if (name != null) {
      return name;
    }
    final int at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  String? _clean(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _messageForPostgrest(PostgrestException error) {
    if (error.code == '42P01' ||
        error.message.toLowerCase().contains('could not find the table')) {
      return 'No encontramos la tabla profiles. Aplica las migraciones de '
          'Supabase antes de iniciar sesión.';
    }
    if (error.code == '42P17') {
      return 'Las políticas RLS de Supabase tienen un problema de recursión. '
          'Aplica la migración de corrección.';
    }
    if (error.code == '42501') {
      return 'No tienes permisos para guardar tu perfil. Revisa las políticas '
          'RLS de Supabase.';
    }
    if (error.code == '23503') {
      return 'Tu usuario todavía no está disponible en Supabase. Intenta de '
          'nuevo en unos segundos.';
    }
    return 'No pudimos guardar tu perfil en Supabase. Intenta de nuevo.';
  }
}
