import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_match_repository.dart';
import '../domain/match.dart';

/// Repositorio de partidos. En la Etapa 4 se sustituirá el valor por la
/// implementación real contra Supabase sin tocar el resto de la app.
final Provider<MockMatchRepository> matchRepositoryProvider =
    Provider<MockMatchRepository>((Ref ref) => const MockMatchRepository());

/// Todos los partidos del usuario (mock, con retardo simulado).
///
/// Es un provider con caché: las pantallas derivan de aquí sin volver a
/// consultar el repositorio.
final FutureProvider<List<Match>> matchesProvider = FutureProvider<List<Match>>(
  (Ref ref) async {
    return ref.watch(matchRepositoryProvider).fetchMatches();
  },
);

/// Detalle de un partido por identificador.
final matchByIdProvider = FutureProvider.family<Match?, String>((
  Ref ref,
  String id,
) async {
  return ref.watch(matchRepositoryProvider).fetchMatchById(id);
});
