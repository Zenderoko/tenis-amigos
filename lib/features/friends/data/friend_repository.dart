import '../domain/friend.dart';

/// Contrato de acceso a amistades y solicitudes.
abstract interface class FriendRepository {
  Future<FriendsOverview> fetchOverview();

  Future<FriendRequestResult> sendRequestByEmail({required String email});

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  });

  Future<void> cancelRequest({required String requestId});
}
