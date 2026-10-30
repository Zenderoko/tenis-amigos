import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de la aplicación.
///
/// Los valores se leen de `.env` (incluido como asset). Ningún secreto debe
/// escribirse directamente en el código ni versionarse en Git.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabasePublishableKey = '',
    this.googleWebClientId = '',
    this.googleAndroidClientId = '',
  });

  factory AppConfig.fromEnvironment() {
    String read(String key) => (dotenv.maybeGet(key) ?? '').trim();

    return AppConfig(
      supabaseUrl: read('SUPABASE_URL'),
      supabaseAnonKey: read('SUPABASE_ANON_KEY'),
      supabasePublishableKey: read('SUPABASE_PUBLISHABLE_KEY'),
      googleWebClientId: read('GOOGLE_WEB_CLIENT_ID'),
      googleAndroidClientId: read('GOOGLE_ANDROID_CLIENT_ID'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabasePublishableKey;

  /// Client ID del OAuth client de tipo "Web".
  ///
  /// En Android se usa como `serverClientId` de Google Sign-In y debe
  /// coincidir con el configurado en el proveedor Google de Supabase.
  final String googleWebClientId;

  /// Client ID del OAuth client de tipo Android.
  ///
  /// Google lo identifica por el package name y el SHA-1 del keystore; no se
  /// envía desde Dart.
  final String googleAndroidClientId;

  String get key => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && key.isNotEmpty;

  bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;

  static AppConfig _current = const AppConfig(
    supabaseUrl: '',
    supabaseAnonKey: '',
  );

  /// Configuración activa cargada en `main`.
  static AppConfig get current => _current;

  static void setCurrent(AppConfig config) {
    _current = config;
  }
}
