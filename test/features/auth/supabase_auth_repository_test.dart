import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tenis_amigos/core/errors/app_failure.dart';
import 'package:tenis_amigos/features/auth/data/supabase_auth_repository.dart';
import 'package:tenis_amigos/features/auth/domain/sign_up_result.dart';

void main() {
  late SupabaseClient client;

  tearDown(() {
    client.dispose();
  });

  SupabaseAuthRepository repositoryReturning(Map<String, dynamic> body) {
    final MockClient httpClient = MockClient(
      (http.Request request) async => http.Response(
        jsonEncode(body),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );

    client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    return SupabaseAuthRepository(client);
  }

  Map<String, dynamic> userJson({
    required String email,
    required List<Map<String, dynamic>> identities,
  }) {
    return <String, dynamic>{
      'id': 'user-id',
      'email': email,
      'aud': 'authenticated',
      'role': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{'full_name': 'Jugador'},
      'identities': identities,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
  }

  test('detecta un correo ya registrado con identidades vacías', () async {
    final SupabaseAuthRepository repository = repositoryReturning(
      userJson(
        email: 'jugador@example.com',
        identities: <Map<String, dynamic>>[],
      ),
    );

    await expectLater(
      repository.signUpWithEmail(
        email: 'jugador@example.com',
        password: 'secreta123',
        displayName: 'Jugador',
      ),
      throwsA(
        isA<AppFailure>().having(
          (AppFailure failure) => failure.code,
          'code',
          'email_already_registered',
        ),
      ),
    );
  });

  test('mantiene la confirmación pendiente para un correo nuevo', () async {
    final SupabaseAuthRepository repository = repositoryReturning(
      userJson(
        email: 'nuevo@example.com',
        identities: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'identity-id',
            'user_id': 'user-id',
            'identity_id': 'identity-id',
            'identity_data': <String, dynamic>{'email': 'nuevo@example.com'},
            'provider': 'email',
            'created_at': '2026-01-01T00:00:00Z',
            'last_sign_in_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ],
      ),
    );

    final SignUpResult result = await repository.signUpWithEmail(
      email: 'nuevo@example.com',
      password: 'secreta123',
      displayName: 'Jugador',
    );

    expect(result.requiresEmailConfirmation, isTrue);
    expect(result.user, isNull);
  });
}
