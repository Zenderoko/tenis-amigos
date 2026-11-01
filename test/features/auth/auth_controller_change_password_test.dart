import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenis_amigos/core/errors/app_failure.dart';
import 'package:tenis_amigos/features/auth/data/auth_providers.dart';
import 'package:tenis_amigos/features/auth/data/auth_repository.dart';
import 'package:tenis_amigos/features/auth/domain/auth_state_change.dart';
import 'package:tenis_amigos/features/auth/domain/auth_user.dart';
import 'package:tenis_amigos/features/auth/domain/sign_up_result.dart';
import 'package:tenis_amigos/features/auth/presentation/auth_controller.dart';

void main() {
  const AuthUser user = AuthUser(
    id: 'user-id',
    email: 'jugador@example.com',
    displayName: 'Jugador',
  );

  late ProviderContainer container;

  tearDown(() {
    container.dispose();
  });

  Future<void> prepare(_FakeAuthRepository repository) async {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await container.read(authControllerProvider.future);
  }

  test('cambia la contraseña después de verificar la actual', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(user: user);
    await prepare(repository);

    await container
        .read(authControllerProvider.notifier)
        .changePassword(currentPassword: 'actual123', newPassword: 'nueva123');

    expect(repository.signInEmail, user.email);
    expect(repository.signInPassword, 'actual123');
    expect(repository.updatedPassword, 'nueva123');
    expect(repository.updateCalls, 1);
  });

  test('rechaza la contraseña actual incorrecta sin actualizar', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(
      user: user,
      signInFailure: const AppFailure(
        'Correo o contraseña incorrectos.',
        code: 'invalid_credentials',
      ),
    );
    await prepare(repository);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: 'incorrecta',
            newPassword: 'nueva123',
          ),
      throwsA(
        isA<AppFailure>().having(
          (AppFailure failure) => failure.code,
          'code',
          'invalid_current_password',
        ),
      ),
    );

    expect(repository.updateCalls, 0);
  });

  test('no cambia la contraseña si no hay sesión', () async {
    final _FakeAuthRepository repository = _FakeAuthRepository(user: null);
    await prepare(repository);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: 'actual123',
            newPassword: 'nueva123',
          ),
      throwsA(
        isA<AppFailure>().having(
          (AppFailure failure) => failure.code,
          'code',
          'no_session',
        ),
      ),
    );

    expect(repository.signInCalls, 0);
    expect(repository.updateCalls, 0);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.user, this.signInFailure});

  final AuthUser? user;
  final AppFailure? signInFailure;

  int signInCalls = 0;
  int updateCalls = 0;
  String? signInEmail;
  String? signInPassword;
  String? updatedPassword;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthStateChange> get authStateChanges =>
      const Stream<AuthStateChange>.empty();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    signInEmail = email;
    signInPassword = password;
    final AppFailure? failure = signInFailure;
    if (failure != null) {
      throw failure;
    }
    return user!;
  }

  @override
  Future<AuthUser> updatePassword({required String newPassword}) async {
    updateCalls++;
    updatedPassword = newPassword;
    return user!;
  }

  @override
  Future<AuthUser> signInWithGoogle({required String idToken}) {
    throw UnimplementedError();
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> resendConfirmationEmail({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }
}
