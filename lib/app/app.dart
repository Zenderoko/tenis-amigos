import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_info.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Widget raíz de TenisAmigos.
class TenisAmigosApp extends StatelessWidget {
  const TenisAmigosApp({super.key, this.router});

  /// Router opcional. En producción se usa el router global; en pruebas se
  /// puede inyectar uno nuevo para aislar el estado de navegación.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router ?? appRouter,
      locale: const Locale('es'),
      supportedLocales: const <Locale>[Locale('es')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
