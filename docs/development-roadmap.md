# Hoja de ruta

Estado de las etapas del proyecto. **No se avanza de etapa sin aprobación.**

| Etapa | Descripción | Estado |
|-------|-------------|--------|
| 0 | Preparación y planificación del entorno | ✅ Completada |
| 1 | Esqueleto de la app (navegación, tema, pantallas) | ✅ Completada |
| 2 | Supabase y autenticación | 🟨 En progreso |
| 3 | Amigos | ⬜ Pendiente |
| 4 | Partidos | ⬜ Pendiente |
| 5 | Calendario y reprogramación | ⬜ Pendiente |
| 6 | Notificaciones | ⬜ Pendiente |
| 7 | Validación del MVP | ⬜ Pendiente |

## Etapa 0 — Preparación (completada)

- Flutter actualizado a 3.47.7 (Dart 3.13.5).
- Android SDK 36 + build-tools instalados; licencias aceptadas.
- `git init` en el proyecto.
- Verificado que un APK de prueba compila pese al aviso de espacios en la ruta
  del SDK (no bloquea; solo afecta a herramientas NDK, que no usamos).

## Etapa 1 — Esqueleto (completada)

Entregado:

- Proyecto Flutter (Android, iOS, web).
- Navegación con GoRouter y barra inferior de cuatro secciones.
- Tema visual (verde de pista, amarillo de pelota, arcilla).
- Pantallas: Inicio, Calendario (semana), Amigos, Perfil, Detalle de partido y
  Nuevo partido (formulario con validaciones).
- Estados de carga, vacío y error reutilizables.
- Widgets y utilidades en `core/`.
- Pruebas: reglas de negocio de partidos, formateo de fechas, avatares y
  navegación.
- Documentación: `README.md`, `docs/architecture.md`.

Verificación ejecutada: `flutter analyze` (sin issues), `flutter test`
(14 pruebas), `flutter build web` y `flutter build apk --debug` (ambos OK).

Todos los datos mostrados son **ficticios** (marcados con un aviso de
prototipo en pantalla).

## Etapa 2 — Supabase y autenticación (en progreso)

Hecho:

- Proyecto Supabase y configuración local con `.env` + `flutter_dotenv`.
- Esquema PostgreSQL versionado con migraciones y RLS.
- Registro e inicio de sesión con Google (Google Sign-In + Supabase Auth).
- Creación automática del perfil en `public.profiles`.
- Perfil real con nombre y foto de Google; el saludo de Inicio usa el nombre.
- Persistencia de sesión y cierre de sesión.
- Manejo de cancelación del flujo de Google y navegación de vuelta.
- Corrección de la recursión de políticas RLS que impedía leer perfiles.
- Registro e inicio de sesión con correo y contraseña.
- Detección de correo ya registrado al crear una cuenta.
- Confirmación de correo con reenvío del enlace desde la app.
- Recuperación de contraseña mediante enlace profundo
  (`tenisamigos://auth-callback`).
- Cambio de contraseña desde Perfil, verificando la contraseña actual.
- Edición del perfil: nombre, foto, nivel y mano dominante.
- Foto de perfil en Supabase Storage (bucket `avatars` con RLS por carpeta).
- Validadores compartidos y pruebas de auth, perfil y navegación.

Pendiente para completar la Etapa 2:

- [x] Registro con correo y contraseña.
- [x] Inicio de sesión con correo y contraseña.
- [x] Confirmación de correo (si está activada en Supabase).
- [x] Recuperación de contraseña.
- [x] Cambio de contraseña desde el perfil.
- [x] Edición del perfil (nombre, foto, nivel y mano dominante).
- [x] Pruebas de los flujos de autenticación y del perfil.
- [ ] Verificación E2E en Android con las migraciones aplicadas.

Verificación automatizada: `flutter analyze` sin issues, `flutter test` con 37
pruebas aprobadas, `flutter build apk --debug` y `flutter build web` correctos.
Falta la prueba manual en un dispositivo/emulador con el proyecto Supabase
configurado (correos reales, redirect URL y Storage).

Criterio de cierre: las vías de acceso con Google y con correo/contraseña
funcionan, la recuperación y el cambio de contraseña están disponibles, el
perfil se puede editar y las pruebas de la etapa pasan.
