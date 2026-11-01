import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_state_change.dart';

/// Conserva el último evento de autenticación relevante para la navegación.
///
/// Se suscribe en `main` justo después de inicializar Supabase, antes de que
/// se construya el router. Así no se pierde un enlace profundo de recuperación
/// aunque el sistema lo entregue durante el arranque.
abstract final class AuthLinkEvents {
  static final ValueNotifier<AuthChangeType?> latest =
      ValueNotifier<AuthChangeType?>(null);

  static StreamSubscription<AuthState>? _subscription;

  static void start() {
    if (_subscription != null) {
      return;
    }

    try {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (AuthState state) {
          switch (state.event) {
            case AuthChangeEvent.passwordRecovery:
              latest.value = AuthChangeType.passwordRecovery;
            case AuthChangeEvent.signedOut:
              latest.value = null;
            default:
              break;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Auth link event error: $error');
        },
      );
    } catch (error) {
      debugPrint('No se pudo escuchar enlaces de autenticación: $error');
    }
  }

  static void clear() {
    latest.value = null;
  }

  static void resetForTesting() {
    _subscription?.cancel();
    _subscription = null;
    latest.value = null;
  }
}
