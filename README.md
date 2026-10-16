# TenisAmigos

Aplicación móvil (Flutter) para organizar partidos de tenis entre amigos:
crear partidos, invitar jugadores, responder invitaciones, consultar el
calendario y reprogramar horarios.

> Estado: **Etapa 1 — Esqueleto de la app**. La interfaz de navegación está
> lista, pero todavía usa **datos ficticios** (mock). El backend (Supabase) se
> conecta a partir de la Etapa 2.

## Estado actual

- Navegación con cuatro secciones: Inicio, Calendario, Amigos y Perfil.
- Tema visual (identidad tenis) y componentes reutilizables.
- Estados de carga, vacío y error.
- Formulario de "Nuevo partido" con validaciones (aún no guarda datos).
- Detalle de partido (mock).

## Requisitos

- Flutter 3.47.7 (stable) y Dart 3.13.5.
- Android SDK 36 (para Android) o un navegador (para web).
- Git.

Verifica el entorno con:

```powershell
flutter doctor
```

## Cómo ejecutar

```powershell
flutter pub get
flutter run
```

Para elegir un dispositivo concreto:

```powershell
flutter devices
flutter run -d chrome      # navegador
flutter run -d <emulador>  # emulador Android
```

## Comprobaciones de calidad

```powershell
flutter analyze
flutter test
```

## Estructura del proyecto

```
lib/
  main.dart                     Punto de entrada (ProviderScope + localización)
  app/
    app.dart                    MaterialApp.router
    router.dart                 Rutas con GoRouter
    scaffold_with_nav_bar.dart  Barra de navegación inferior
    theme/                      Colores y tema visual
  core/
    constants/                  Marca y datos mock
    utils/                      Formato de fechas, avatares
    widgets/                    Componentes reutilizables (estados, tarjetas)
  features/
    home/                       Pantalla de Inicio
    calendar/                   Pantalla de Calendario
    friends/                    Amigos (domain/data/presentation)
    matches/                    Partidos (domain/data/presentation)
    profile/                    Perfil
```

## Documentación

- [`docs/architecture.md`](docs/architecture.md): arquitectura y decisiones.
- [`docs/development-roadmap.md`](docs/development-roadmap.md): etapas y estado.
