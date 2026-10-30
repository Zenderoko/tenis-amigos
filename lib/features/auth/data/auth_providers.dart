import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'google_auth_service.dart';
import 'supabase_auth_repository.dart';

/// Servicio nativo de Google Sign-In.
final Provider<GoogleAuthService> googleAuthServiceProvider =
    Provider<GoogleAuthService>((Ref ref) => GoogleAuthService());

/// Repositorio de autenticación (Supabase Auth).
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => SupabaseAuthRepository());
