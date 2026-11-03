# TenisAmigos

Aplicación móvil (Flutter) para organizar partidos de tenis entre amigos:
crear partidos, invitar jugadores, responder invitaciones, consultar el
calendario y reprogramar horarios.

> Estado: **Etapa 3 — Amigos (completada)**. La autenticación, el perfil y las
> amistades usan Supabase. Inicio, Invitaciones, Calendario y partidos siguen con
> datos ficticios (mock). La invitación por enlace queda pendiente de una URL
> pública de la app.

## Estado actual

- Registro e inicio de sesión con Google (Supabase Auth).
- Registro e inicio de sesión con correo y contraseña.
- Detección de correo ya registrado al crear una cuenta.
- Confirmación de correo y reenvío del enlace desde la app.
- Recuperación de contraseña mediante enlace profundo.
- Cambio de contraseña desde el perfil, verificando la contraseña actual.
- Perfil real del usuario en `public.profiles` y cierre de sesión.
- Edición del perfil: nombre, foto, nivel y mano dominante.
- Foto de perfil en el bucket público `avatars` de Supabase Storage.
- Amistades reales: solicitudes por correo exacto, aceptar, rechazar, cancelar y
  lista de amigos con su foto y nivel.
- Sesión persistente entre reinicios.
- Navegación con cuatro secciones: Inicio, Invitaciones, Amigos y Perfil.
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
3. En Supabase, añade `tenisamigos://auth-callback` a las Redirect URLs y
   revisa la configuración de correo (confirmación y recuperación).
4. Añade una cuenta de Google al emulador Android.

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
    auth/                       Google, correo/contraseña y sesión de Supabase
    home/                       Pantalla de Inicio
    calendar/                   Pantalla de Calendario
    friends/                    Amistades reales (solicitudes y lista)
    invitations/                Invitaciones (domain/data/presentation)
    matches/                    Partidos (domain/data/presentation)
    profile/                    Perfil real del usuario y edición
```

## Documentación

- [`docs/architecture.md`](docs/architecture.md): arquitectura y decisiones.
- [`docs/development-roadmap.md`](docs/development-roadmap.md): etapas y estado.
- [`docs/setup-supabase.md`](docs/setup-supabase.md): configuración de Supabase.
