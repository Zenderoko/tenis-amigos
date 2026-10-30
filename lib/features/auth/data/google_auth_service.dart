import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';

/// Encapsula la inicialización y el flujo nativo de Google Sign-In.
///
/// La inicialización es perezosa y se ejecuta una sola vez. Así la app puede
/// arrancar aunque Google todavía no esté configurado en el entorno local.
class GoogleAuthService {
  GoogleAuthService({String? webClientId})
    : _webClientId = webClientId ?? AppConfig.current.googleWebClientId;

  final String _webClientId;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    final String clientId = _webClientId.trim();
    if (clientId.isEmpty) {
      throw const AppFailure(
        'Falta GOOGLE_WEB_CLIENT_ID en .env. Revisa la configuración de Google.',
        code: 'missing_web_client_id',
      );
    }

    try {
      await GoogleSignIn.instance.initialize(serverClientId: clientId);
    } on GoogleSignInException catch (error) {
      debugPrint(
        'Google Sign-In init error: ${error.code} ${error.description}',
      );
      throw AppFailure(_messageForGoogleError(error), code: error.code.name);
    } catch (error) {
      debugPrint('Google Sign-In init error: $error');
      throw const AppFailure(
        'No pudimos inicializar Google. Intenta de nuevo en un momento.',
        code: 'google_init_error',
      );
    }
  }

  /// Abre el selector de cuentas de Google y devuelve el ID token.
  ///
  /// El token se envía a Supabase para crear o recuperar la sesión. No debe
  /// registrarse en logs.
  Future<String> obtainIdToken() async {
    await _ensureInitialized();

    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AppFailure(
          'Google no devolvió un token válido. Intenta de nuevo.',
          code: 'missing_id_token',
        );
      }

      return idToken;
    } on AppFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      debugPrint('Google Sign-In error: ${error.code} ${error.description}');
      throw AppFailure(_messageForGoogleError(error), code: error.code.name);
    } catch (error) {
      debugPrint('Google Sign-In error: $error');
      throw const AppFailure(
        'No pudimos iniciar sesión con Google. Intenta de nuevo.',
        code: 'google_sign_in_error',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Google Sign-In sign out error: $error');
    }
  }

  String _messageForGoogleError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Cancelaste el inicio de sesión con Google.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'La configuración de Google no es válida. Revisa el SHA-1, '
            'el package name y el OAuth client de Android.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'El proveedor de Google no está disponible en este dispositivo.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No se pudo abrir la ventana de Google. Intenta de nuevo.';
      case GoogleSignInExceptionCode.interrupted:
        return 'El inicio de sesión se interrumpió. Intenta de nuevo.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Hay otra cuenta activa. Cierra sesión e inténtalo de nuevo.';
      case GoogleSignInExceptionCode.unknownError:
        return 'No pudimos iniciar sesión con Google. Intenta de nuevo.';
    }
  }
}
