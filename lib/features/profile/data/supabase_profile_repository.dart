import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/dominant_hand.dart';
import '../domain/tennis_level.dart';
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

  /// Guarda los datos editables del perfil.
  Future<UserProfile> updateProfile({
    required String userId,
    required String email,
    required String displayName,
    TennisLevel? tennisLevel,
    DominantHand? dominantHand,
    String? avatarUrl,
  });

  /// Sube la foto al bucket `avatars` y devuelve su URL pública.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
    String contentType = 'image/jpeg',
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

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String email,
    required String displayName,
    TennisLevel? tennisLevel,
    DominantHand? dominantHand,
    String? avatarUrl,
  }) async {
    final String name = displayName.trim();
    if (name.isEmpty) {
      throw const AppFailure('Ingresa tu nombre.', code: 'empty_display_name');
    }

    final Map<String, dynamic> values = <String, dynamic>{
      'display_name': name,
      'tennis_level': tennisLevel?.value,
      'dominant_hand': dominantHand?.value,
    };
    if (avatarUrl != null) {
      values['avatar_url'] = avatarUrl;
    }

    try {
      final Map<String, dynamic> updated = await _supabase
          .from('profiles')
          .update(values)
          .eq('id', userId)
          .select()
          .single();
      return UserProfile.fromMap(updated, email: email);
    } on PostgrestException catch (error) {
      debugPrint('Profile update error: ${error.code} ${error.message}');
      throw AppFailure(_messageForPostgrest(error), code: error.code);
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String extension,
    String contentType = 'image/jpeg',
  }) async {
    final String normalizedExtension = extension.toLowerCase().replaceFirst(
      '.',
      '',
    );
    final String path =
        '$userId/avatar-${DateTime.now().millisecondsSinceEpoch}.'
        '${normalizedExtension.isEmpty ? 'jpg' : normalizedExtension}';

    try {
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '3600',
              upsert: true,
            ),
          );
      return _supabase.storage.from('avatars').getPublicUrl(path);
    } on StorageException catch (error) {
      debugPrint('Avatar upload error: ${error.statusCode} ${error.message}');
      if (error.statusCode == '404' ||
          error.message.toLowerCase().contains('bucket')) {
        throw const AppFailure(
          'No encontramos el bucket avatars. Aplica la migración de Storage '
          'en Supabase.',
          code: 'avatars_bucket_missing',
        );
      }
      throw const AppFailure(
        'No pudimos subir tu foto. Intenta con otra imagen.',
        code: 'avatar_upload_error',
      );
    }
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
