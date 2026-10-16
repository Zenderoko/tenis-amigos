import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/presentation/calendar_screen.dart';
import '../features/friends/presentation/friends_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/matches/presentation/create_match_screen.dart';
import '../features/matches/presentation/match_detail_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'scaffold_with_nav_bar.dart';

/// Rutas nombradas (útiles para navegar sin repetir cadenas).
abstract final class AppRoutes {
  static const String home = '/inicio';
  static const String calendar = '/calendario';
  static const String friends = '/amigos';
  static const String profile = '/perfil';
  static const String matchDetail = '/partido';
  static const String createMatch = '/nuevo-partido';
}

/// Router de la aplicación.
///
/// Las cuatro secciones principales viven dentro de un
/// [StatefulShellRoute] para conservar el estado de cada pestaña. Las pantallas
/// de detalle y creación se abren por encima, sin barra de navegación.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder:
          (
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
              path: AppRoutes.calendar,
              builder: (BuildContext context, GoRouterState state) =>
                  const CalendarScreen(),
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
