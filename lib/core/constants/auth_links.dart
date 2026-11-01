import 'package:flutter/foundation.dart';

/// URLs de retorno usadas por los enlaces de Supabase Auth.
abstract final class AuthLinks {
  /// Esquema propio de la app, registrado en Android e iOS.
  ///
  /// Debe ser un esquema URI válido (sin guiones bajos).
  static const String scheme = 'tenisamigos';

  /// Host del callback de autenticación.
  static const String callbackHost = 'auth-callback';

  /// URL que Supabase usa para devolver al usuario a la app.
  ///
  /// En web se usa el origen actual, porque un esquema propio no existe en el
  /// navegador. Esta URL debe estar autorizada en Supabase → Authentication →
  /// URL Configuration.
  static String get redirectUrl {
    if (kIsWeb) {
      final Uri base = Uri.base;
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '/',
      ).toString();
    }
    return '$scheme://$callbackHost';
  }
}
