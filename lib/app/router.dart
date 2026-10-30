import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/friends/presentation/friends_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/invitations/presentation/invitations_screen.dart';
import '../features/matches/presentation/create_match_screen.dart';
import '../features/matches/presentation/match_detail_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'scaffold_with_nav_bar.dart';

/// Rutas nombradas (útiles para navegar sin repetir cadenas).
abstract final class AppRoutes {
  static const String home = '/inicio';
  static const String invitations = '/invitaciones';
  static const String friends = '/amigos';
  static const String profile = '/perfil';
  static const String matchDetail = '/partido';
  static const String createMatch = '/nuevo-partido';
  static const String login = '/login';
  static const String register = '/registro';
}

/// Router de la aplicación.
///
/// Las cuatro secciones principales viven dentro de un
/// [StatefulShellRoute] para conservar el estado de cada pestaña. Las pantallas
/// de detalle y creación se abren por encima, sin barra de navegación.
///
/// Las variables de nivel superior se inicializan de forma perezosa, así que
/// `main` ya restauró la sesión de Supabase cuando se decide la pantalla
/// inicial.
final GoRouter appRouter = createRouter();

/// Crea un router independiente. Útil para pruebas y para reiniciar el estado
/// de navegación.
GoRouter createRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation ?? _initialLocation(),
    refreshListenable: _AuthRefreshNotifier(),
    redirect: _redirect,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.invitations,
                builder: (BuildContext context, GoRouterState state) =>
                    const InvitationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.friends,
                builder: (BuildContext context, GoRouterState state) =>
                    const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.matchDetail}/:id',
        builder: (BuildContext context, GoRouterState state) =>
            MatchDetailScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.createMatch,
        builder: (BuildContext context, GoRouterState state) =>
            const CreateMatchScreen(),
      ),
    ],
  );
}

String _initialLocation() {
  return _hasSession() ? AppRoutes.home : AppRoutes.login;
}

String? _redirect(BuildContext context, GoRouterState state) {
  final bool hasSession = _hasSession();
  final bool isAuthRoute =
      state.matchedLocation == AppRoutes.login ||
      state.matchedLocation == AppRoutes.register;

  if (!hasSession && !isAuthRoute) {
    return AppRoutes.login;
  }
  if (hasSession && isAuthRoute) {
    return AppRoutes.home;
  }
  return null;
}

bool _hasSession() {
  try {
    return Supabase.instance.client.auth.currentSession != null;
  } catch (_) {
    // Supabase aún no está inicializado (por ejemplo en pruebas de widgets).
    return false;
  }
}

/// Notifica al router cuando Supabase restaura, actualiza o cierra la sesión.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    try {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) => notifyListeners(),
      );
    } catch (_) {
      // En pruebas no hay cliente de Supabase inicializado.
    }
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
