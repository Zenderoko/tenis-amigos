import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tenis_amigos/app/router.dart';
import 'package:tenis_amigos/core/errors/app_failure.dart';
import 'package:tenis_amigos/features/auth/domain/auth_user.dart';
import 'package:tenis_amigos/features/auth/presentation/auth_controller.dart';
import 'package:tenis_amigos/features/friends/data/friend_repository.dart';
import 'package:tenis_amigos/features/friends/data/friends_realtime.dart';
import 'package:tenis_amigos/features/friends/domain/friend.dart';
import 'package:tenis_amigos/features/friends/presentation/friend_profile_screen.dart';
import 'package:tenis_amigos/features/friends/presentation/friends_providers.dart';
import 'package:tenis_amigos/features/friends/presentation/friends_screen.dart';
import 'package:tenis_amigos/features/profile/domain/dominant_hand.dart';
import 'package:tenis_amigos/features/profile/domain/tennis_level.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 2, 12);

  Future<void> pumpFriends(
    WidgetTester tester,
    _FakeFriendRepository repository, {
    GoRouter? router,
    _FakeFriendsRealtime? realtime,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          friendRepositoryProvider.overrideWithValue(repository),
          friendsRealtimeProvider.overrideWithValue(
            realtime ?? _FakeFriendsRealtime(),
          ),
        ],
        child: router == null
            ? const MaterialApp(home: FriendsScreen())
            : MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el estado vacío con acción para agregar', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(),
    );

    await pumpFriends(tester, repository);

    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);
    expect(find.text('Agregar amigo'), findsOneWidget);
  });

  testWidgets('Realtime refresca la lista cuando cambia una amistad', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(),
    );
    final _FakeFriendsRealtime realtime = _FakeFriendsRealtime();

    await pumpFriends(tester, repository, realtime: realtime);
    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);

    repository.overview = const FriendsOverview(
      friends: <Friend>[Friend(id: 'u2', displayName: 'Camila Rojas')],
    );
    realtime.emit();
    await tester.pumpAndSettle();

    expect(find.text('Camila Rojas'), findsOneWidget);
    expect(find.text('Mis amigos (1)'), findsOneWidget);
    expect(find.text('Agrega a tu primer amigo'), findsNothing);
  });

  testWidgets('acepta una solicitud y mueve a la persona a amigos', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      FriendsOverview(
        incomingRequests: <FriendRequest>[
          FriendRequest(
            id: 'r1',
            sender: const Friend(id: 'u2', displayName: 'Camila Rojas'),
            receivedAt: now,
          ),
        ],
      ),
    );

    await pumpFriends(tester, repository);
    expect(find.text('Camila Rojas'), findsOneWidget);
    expect(find.text('Solicitudes recibidas (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friend-request-accept-r1')));
    await tester.pumpAndSettle();

    expect(repository.respondedId, 'r1');
    expect(repository.lastAccept, isTrue);
    expect(find.text('Camila Rojas ahora es tu amigo.'), findsOneWidget);
    expect(find.text('Mis amigos (1)'), findsOneWidget);
    expect(find.text('Solicitudes recibidas (1)'), findsNothing);
  });

  testWidgets('rechaza una solicitud y deja la lista vacía', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      FriendsOverview(
        incomingRequests: <FriendRequest>[
          FriendRequest(
            id: 'r1',
            sender: const Friend(id: 'u2', displayName: 'Camila Rojas'),
            receivedAt: now,
          ),
        ],
      ),
    );

    await pumpFriends(tester, repository);
    await tester.tap(find.byKey(const Key('friend-request-reject-r1')));
    await tester.pumpAndSettle();

    expect(repository.lastAccept, isFalse);
    expect(find.text('Solicitud rechazada.'), findsOneWidget);
    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);
  });

  testWidgets('envía una solicitud desde el diálogo', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(),
    );
    repository.result = const FriendRequestResult(
      outcome: FriendRequestOutcome.sent,
      targetName: 'Matías Fuentes',
    );

    await pumpFriends(tester, repository);
    await tester.tap(find.byTooltip('Agregar amigo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-friend-email')),
      'amigo@example.com',
    );
    await tester.tap(find.byKey(const Key('add-friend-submit')));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'amigo@example.com');
    expect(find.text('Solicitud enviada a Matías Fuentes.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('valida el correo antes de enviar', (WidgetTester tester) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(),
    );

    await pumpFriends(tester, repository);
    await tester.tap(find.byTooltip('Agregar amigo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-friend-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(repository.lastEmail, isNull);
  });

  testWidgets('cancela una solicitud enviada', (WidgetTester tester) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      FriendsOverview(
        outgoingRequests: <SentFriendRequest>[
          SentFriendRequest(
            id: 's1',
            recipient: const Friend(id: 'u3', displayName: 'Diego Soto'),
            sentAt: now,
          ),
        ],
      ),
    );

    await pumpFriends(tester, repository);
    expect(find.text('Solicitudes enviadas (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friend-request-cancel-s1')));
    await tester.pumpAndSettle();

    expect(repository.cancelledId, 's1');
    expect(find.text('Solicitud a Diego Soto cancelada.'), findsOneWidget);
    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);
  });

  testWidgets('abre el perfil y elimina la amistad', (
    WidgetTester tester,
  ) async {
    const Friend camila = Friend(
      id: 'u2',
      displayName: 'Camila Rojas',
      tennisLevel: TennisLevel.intermediate,
      dominantHand: DominantHand.right,
    );
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(friends: <Friend>[camila]),
    );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.friends,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.friends,
          builder: (BuildContext context, GoRouterState state) =>
              const FriendsScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.friendProfile}/:id',
          builder: (BuildContext context, GoRouterState state) =>
              FriendProfileScreen(friend: state.extra! as Friend),
        ),
      ],
    );

    await pumpFriends(tester, repository, router: router);
    await tester.tap(find.text('Camila Rojas'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil de amigo'), findsOneWidget);
    expect(find.text('Nivel: Intermedio'), findsOneWidget);
    expect(find.text('Diestro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-friend-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-friend')));
    await tester.pumpAndSettle();

    expect(repository.removedFriendId, 'u2');
    expect(find.text('Camila Rojas ya no está en tus amigos.'), findsOneWidget);
    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);
  });

  testWidgets('si falla la eliminación permanece en el perfil', (
    WidgetTester tester,
  ) async {
    const Friend camila = Friend(id: 'u2', displayName: 'Camila Rojas');
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(friends: <Friend>[camila]),
    );
    repository.removeFailure = const AppFailure(
      'No pudimos eliminar la amistad.',
      code: 'remove_failed',
    );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.friends,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.friends,
          builder: (BuildContext context, GoRouterState state) =>
              const FriendsScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.friendProfile}/:id',
          builder: (BuildContext context, GoRouterState state) =>
              FriendProfileScreen(friend: state.extra! as Friend),
        ),
      ],
    );

    await pumpFriends(tester, repository, router: router);
    await tester.tap(find.text('Camila Rojas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-friend-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-friend')));
    await tester.pumpAndSettle();

    expect(repository.removedFriendId, 'u2');
    expect(find.text('No pudimos eliminar la amistad.'), findsOneWidget);
    expect(find.text('Perfil de amigo'), findsOneWidget);
  });

  testWidgets('muestra el error y permite reintentar', (
    WidgetTester tester,
  ) async {
    final _FakeFriendRepository repository = _FakeFriendRepository(
      const FriendsOverview(),
    );
    repository.fetchFailure = const AppFailure('Sin conexión', code: 'network');

    await pumpFriends(tester, repository);
    expect(
      find.textContaining('No pudimos cargar tus amigos.'),
      findsOneWidget,
    );

    repository.fetchFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Agrega a tu primer amigo'), findsOneWidget);
  });
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async {
    return const AuthUser(id: 'current-user', email: 'me@example.com');
  }
}

class _FakeFriendRepository implements FriendRepository {
  _FakeFriendRepository(this.overview);

  FriendsOverview overview;
  FriendRequestResult result = const FriendRequestResult(
    outcome: FriendRequestOutcome.sent,
    targetName: 'tu amigo',
  );
  AppFailure? fetchFailure;
  AppFailure? sendFailure;
  AppFailure? removeFailure;
  String? lastEmail;
  String? respondedId;
  bool? lastAccept;
  String? cancelledId;
  String? removedFriendId;

  @override
  Future<FriendsOverview> fetchOverview() async {
    final AppFailure? failure = fetchFailure;
    if (failure != null) {
      throw failure;
    }
    return overview;
  }

  @override
  Future<FriendRequestResult> sendRequestByEmail({
    required String email,
  }) async {
    lastEmail = email;
    final AppFailure? failure = sendFailure;
    if (failure != null) {
      throw failure;
    }
    return result;
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    respondedId = requestId;
    lastAccept = accept;
    final List<FriendRequest> incoming = overview.incomingRequests
        .where((FriendRequest request) => request.id != requestId)
        .toList();
    final List<Friend> friends = <Friend>[...overview.friends];
    if (accept) {
      final FriendRequest request = overview.incomingRequests.firstWhere(
        (FriendRequest request) => request.id == requestId,
      );
      friends.add(request.sender);
    }
    overview = FriendsOverview(
      friends: friends,
      incomingRequests: incoming,
      outgoingRequests: overview.outgoingRequests,
    );
  }

  @override
  Future<void> cancelRequest({required String requestId}) async {
    cancelledId = requestId;
    overview = FriendsOverview(
      friends: overview.friends,
      incomingRequests: overview.incomingRequests,
      outgoingRequests: overview.outgoingRequests
          .where((SentFriendRequest request) => request.id != requestId)
          .toList(),
    );
  }

  @override
  Future<void> removeFriend({required String friendId}) async {
    removedFriendId = friendId;
    final AppFailure? failure = removeFailure;
    if (failure != null) {
      throw failure;
    }
    overview = FriendsOverview(
      friends: overview.friends
          .where((Friend friend) => friend.id != friendId)
          .toList(),
      incomingRequests: overview.incomingRequests,
      outgoingRequests: overview.outgoingRequests,
    );
  }
}

class _FakeFriendsRealtime implements FriendsRealtime {
  void Function()? _onChanged;

  @override
  void start(void Function() onChanged) {
    _onChanged = onChanged;
  }

  @override
  void stop() {
    _onChanged = null;
  }

  void emit() => _onChanged?.call();
}
