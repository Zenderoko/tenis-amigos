# TenisAmigos

Aplicación móvil (Flutter) para organizar partidos de tenis entre amigos:
crear partidos, invitar jugadores, responder invitaciones, consultar el
calendario y reprogramar horarios.

> Estado: **Etapa 2 — Supabase y autenticación (en progreso)**. El registro y
> el inicio de sesión con Google ya usan Supabase. Las demás pantallas todavía
> muestran datos ficticios (mock).

## Estado actual

- Registro e inicio de sesión con Google (Supabase Auth).
- Perfil real del usuario en `public.profiles` y cierre de sesión.
- Sesión persistente entre reinicios.
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

## Configuración

1. Copia `.env.example` a `.env` y completa Supabase y Google OAuth.
2. Aplica las migraciones de `supabase/migrations/` en Supabase (SQL Editor).
3. Añade una cuenta de Google al emulador Android.

Detalle paso a paso en
[`docs/setup-supabase.md`](docs/setup-supabase.md).

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
    config/                     Configuración leída de .env
    errors/                     Errores controlados
    constants/                  Marca y datos mock
    utils/                      Formato de fechas, avatares
    widgets/                    Componentes reutilizables (estados, tarjetas)
  features/
    auth/                       Google Sign-In y sesión de Supabase
    home/                       Pantalla de Inicio
    calendar/                   Pantalla de Calendario
    friends/                    Amigos (domain/data/presentation)
    matches/                    Partidos (domain/data/presentation)
    profile/                    Perfil real del usuario
```

## Documentación

- [`docs/architecture.md`](docs/architecture.md): arquitectura y decisiones.
- [`docs/development-roadmap.md`](docs/development-roadmap.md): etapas y estado.
- [`docs/setup-supabase.md`](docs/setup-supabase.md): configuración de Supabase.
