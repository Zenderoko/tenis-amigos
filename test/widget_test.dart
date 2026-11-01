import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tenis_amigos/app/app.dart';
import 'package:tenis_amigos/app/router.dart';
import 'package:tenis_amigos/features/auth/data/auth_link_events.dart';

void main() {
  setUp(AuthLinkEvents.resetForTesting);

  testWidgets('La app arranca en la pantalla de inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('Se puede abrir el registro desde el inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Registrarme con Google'), findsOneWidget);
  });

  testWidgets('Se puede volver del registro al inicio de sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Registrarme con Google'), findsNothing);
  });

  testWidgets('El inicio de sesión permite cancelar la salida', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir de TenisAmigos?'), findsOneWidget);

    await tester.tap(find.text('Seguir aquí'));
    await tester.pumpAndSettle();

    expect(find.text('¿Salir de TenisAmigos?'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('El inicio de sesión valida correo y contraseña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa una contraseña.'), findsOneWidget);
  });

  testWidgets('Se puede abrir y cerrar la recuperación de contraseña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TenisAmigosApp(
          router: createRouter(initialLocation: AppRoutes.login),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.byKey(const Key('forgot-email')), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
