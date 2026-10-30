import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadConfiguration();

  // Carga los datos de localización usados por `intl` (fechas en español).
  await initializeDateFormatting('es');

  await _initializeSupabase(AppConfig.current);

  runApp(const ProviderScope(child: TenisAmigosApp()));
}

Future<void> _loadConfiguration() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('No se pudo cargar .env: $error');
  }

  AppConfig.setCurrent(AppConfig.fromEnvironment());
}

Future<void> _initializeSupabase(AppConfig config) async {
  if (!config.isSupabaseConfigured) {
    debugPrint(
      'Supabase no está configurado. Completa SUPABASE_URL y '
      'SUPABASE_PUBLISHABLE_KEY en .env.',
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.key,
    );
  } catch (error) {
    debugPrint('No se pudo inicializar Supabase: $error');
  }
}
