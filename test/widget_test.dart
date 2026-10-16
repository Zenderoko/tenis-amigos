import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tenis_amigos/app/app.dart';

void main() {
  testWidgets('La app arranca en Inicio y muestra la barra de navegación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TenisAmigosApp()));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsWidgets);

    // Los cuatro destinos de la barra inferior están presentes.
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Amigos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('Se puede navegar a la pestaña de Amigos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TenisAmigosApp()));
    await tester.pump();

    await tester.tap(find.text('Amigos'));
    await tester.pumpAndSettle();

    expect(find.text('Mis amigos'), findsOneWidget);
  });
}
