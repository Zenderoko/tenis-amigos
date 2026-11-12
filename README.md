# TenisAmigos

Aplicación móvil (Flutter) para organizar partidos de tenis entre amigos:
crear partidos, invitar jugadores, responder invitaciones, consultar el
calendario y reprogramar horarios.

> Estado: **Etapa 5 — Calendario y reprogramación (completada)**.
> Autenticación, perfil, amistades, partidos, cancelación y reprogramación usan
> Supabase. La invitación de amistades por enlace queda pendiente de una URL
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
- Perfil de amigo al tocar su tarjeta, con opción de eliminar la amistad.
- Sincronización en vivo de amistades y partidos con Supabase Realtime.
- Sesión persistente entre reinicios.
- Navegación con cuatro secciones: Inicio, Partidos, Amigos y Perfil.
- Ventana de Partidos con pestañas: En curso, Invitaciones e Historial.
- Tema visual (identidad tenis) y componentes reutilizables.
- Estados de carga, vacío y error.
- Partidos reales: creación con modalidad, fecha, hora, duración, lugar e
  invitados; selector de amistades aceptadas.
- Invitaciones reales: aceptar o rechazar desde la lista y el detalle.
- El organizador puede invitar jugadores adicionales o reemplazos hasta completar
  el cupo.
- Horarios guardados en UTC y mostrados en `America/Santiago` con el paquete
  `timezone`.
- Detalle de partido con jugadores, respuestas, cupo e historial de eventos.
- Cancelación del partido por el organizador y retiro de jugadores confirmados.
- El organizador puede eliminar a un jugador que no podrá asistir.
- Reprogramación: el organizador propone un nuevo horario y los jugadores
  confirmados lo aprueban o rechazan.
- Calendario con vistas semanal y mensual, indicadores por estado y leyenda.

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
    constants/                  Marca y enlaces
    utils/                      Fechas, avatares y zonas horarias
    widgets/                    Componentes reutilizables (estados, tarjetas)
  features/
    auth/                       Google, correo/contraseña y sesión de Supabase
    home/                       Pantalla de Inicio
    calendar/                   Pantalla de Calendario
    friends/                    Amistades reales (solicitudes y lista)
    matches/                    Partidos, invitaciones e historial
    profile/                    Perfil real del usuario y edición
```

## Documentación

- [`docs/architecture.md`](docs/architecture.md): arquitectura y decisiones.
- [`docs/business-rules.md`](docs/business-rules.md): reglas de partidos.
- [`docs/development-roadmap.md`](docs/development-roadmap.md): etapas y estado.
- [`docs/setup-supabase.md`](docs/setup-supabase.md): configuración de Supabase.
