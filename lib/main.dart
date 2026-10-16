import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga los datos de localización usados por `intl` (fechas en español).
  await initializeDateFormatting('es');

  runApp(const ProviderScope(child: TenisAmigosApp()));
}
