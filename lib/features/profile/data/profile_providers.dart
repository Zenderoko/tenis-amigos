import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/user_profile.dart';
import 'supabase_profile_repository.dart';

/// Repositorio del perfil respaldado por Supabase.
final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => SupabaseProfileRepository());

/// Perfil del usuario autenticado.
///
/// Depende de la sesión activa: si no hay usuario, falla con un error
/// controlado.
final FutureProvider<UserProfile> profileProvider = FutureProvider<UserProfile>(
  (Ref ref) async {
    final ProfileRepository repository = ref.watch(profileRepositoryProvider);
    final AuthUser? user = await ref.watch(authControllerProvider.future);

    if (user == null) {
      throw const AppFailure(
        'No hay una sesión activa. Inicia sesión para ver tu perfil.',
        code: 'no_active_session',
      );
    }

    return repository.fetchProfile(userId: user.id, email: user.email);
  },
);
