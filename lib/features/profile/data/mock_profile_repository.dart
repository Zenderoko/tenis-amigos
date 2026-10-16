import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/mock_data.dart';
import '../domain/user_profile.dart';

/// Perfil de usuario con datos FICTICIOS, solo para prototipos visuales.
///
/// Se reemplazará por datos reales de Supabase en la Etapa 2.
class MockProfileRepository {
  const MockProfileRepository();

  Future<UserProfile> fetchProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return UserProfile(
      id: kMockCurrentUserId,
      displayName: kMockCurrentUserName,
      email: kMockCurrentUserEmail,
      memberSince: DateTime(2026, 1, 15),
      tennisLevel: 'Intermedio',
      dominantHand: 'Diestro',
    );
  }
}

final Provider<MockProfileRepository> profileRepositoryProvider =
    Provider<MockProfileRepository>((Ref ref) => const MockProfileRepository());

/// Perfil del usuario actual (mock).
final FutureProvider<UserProfile> profileProvider =
    FutureProvider<UserProfile>((Ref ref) async {
  return ref.watch(profileRepositoryProvider).fetchProfile();
});
