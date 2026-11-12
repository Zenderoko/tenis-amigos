import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_link_events.dart';
import '../features/auth/domain/auth_state_change.dart';
import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/friends/domain/friend.dart';
import '../features/friends/presentation/friend_profile_screen.dart';
import '../features/friends/presentation/friends_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/matches/presentation/create_match_screen.dart';
import '../features/matches/presentation/match_detail_screen.dart';
import '../features/matches/presentation/matches_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'scaffold_with_nav_bar.dart';

/// Rutas nombradas (útiles para navegar sin repetir cadenas).
abstract final class AppRoutes {
  static const String home = '/inicio';
  static const String matches = '/partidos';
  static const String friends = '/amigos';
  static const String friendProfile = '/amigo';
  static const String profile = '/perfil';
  static const String matchDetail = '/partido';
  static const String createMatch = '/nuevo-partido';
  static const String login = '/login';
  static const String register = '/registro';
  static const String forgotPassword = '/recuperar-contrasena';
  static const String resetPassword = '/restablecer-contrasena';
  static const String editProfile = '/perfil/editar';
  static const String changePassword = '/perfil/cambiar-contrasena';
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
    refreshListenable: Listenable.merge(<Listenable>[
      _AuthRefreshNotifier(),
      AuthLinkEvents.latest,
    ]),
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
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ResetPasswordScreen(),
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
                path: AppRoutes.matches,
                builder: (BuildContext context, GoRouterState state) =>
                    const MatchesScreen(),
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
        path: '${AppRoutes.friendProfile}/:id',
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          if (extra is Friend) {
            return FriendProfileScreen(friend: extra);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Perfil de amigo')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pudimos abrir este perfil.\n'
                  'Vuelve a la lista de amigos e inténtalo de nuevo.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.createMatch,
        builder: (BuildContext context, GoRouterState state) =>
            const CreateMatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (BuildContext context, GoRouterState state) =>
            const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ChangePasswordScreen(),
      ),
    ],
  );
}

String _initialLocation() {
  if (AuthLinkEvents.latest.value == AuthChangeType.passwordRecovery) {
    return AppRoutes.resetPassword;
  }
  return _hasSession() ? AppRoutes.home : AppRoutes.login;
}

String? _redirect(BuildContext context, GoRouterState state) {
  final bool hasSession = _hasSession();
  final bool isAuthRoute =
      state.matchedLocation == AppRoutes.login ||
      state.matchedLocation == AppRoutes.register ||
      state.matchedLocation == AppRoutes.forgotPassword;
  final bool isPasswordReset = state.matchedLocation == AppRoutes.resetPassword;

  // Un enlace de recuperación debe abrir la pantalla de nueva contraseña
  // incluso si Supabase ya restauró una sesión temporal.
  if (AuthLinkEvents.latest.value == AuthChangeType.passwordRecovery &&
      !isPasswordReset) {
    return AppRoutes.resetPassword;
  }

  if (!hasSession && !isAuthRoute && !isPasswordReset) {
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
