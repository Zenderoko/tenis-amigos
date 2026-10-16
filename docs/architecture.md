# Arquitectura

## Visión general

TenisAmigos es un **monolito móvil** con backend administrado (Supabase). No
usa microservicios. La app se organiza **por funcionalidades (features)**, con
responsabilidades separadas.

## Stack

| Capa | Tecnología | Notas |
|------|------------|-------|
| UI | Flutter + Dart | Android e iOS (iOS no compila en Windows) |
| Estado | Riverpod | `flutter_riverpod` 3.x |
| Navegación | GoRouter | `StatefulShellRoute` para las 4 secciones |
| Fechas | `intl` | Formato en español (`es`) |
| Backend | Supabase (PostgreSQL + Auth) | A partir de la Etapa 2 |

## Capas por feature

Cada funcionalidad agrupa lo que necesita; **no se crean carpetas vacías**:

- **presentation**: pantallas, widgets y providers de estado de interfaz.
- **domain**: modelos y reglas de negocio (por ejemplo, reglas de un partido).
- **data**: repositorios y acceso a datos (mock ahora, Supabase después).

La interfaz **no** ejecuta consultas directas a la base de datos: siempre pasa
por un repositorio. Esto permite cambiar el mock por Supabase sin tocar las
pantallas.

## Flujo de dependencias

```
presentation  →  data (repositorio)  →  Supabase
      │
      └──────────→  domain (modelos/reglas)
```

## Navegación

`lib/app/router.dart` define:

- `StatefulShellRoute.indexedStack` con cuatro ramas (Inicio, Calendario,
  Amigos, Perfil) para conservar el estado de cada pestaña.
- Rutas de detalle y creación (`/partido/:id`, `/nuevo-partido`) fuera del
  shell, para que se abran por encima sin barra inferior.

## Decisiones registradas

- **Riverpod 3.4.3**: los providers son *autoDispose = false* por defecto; el
  estado se cachea. `AsyncValue.value` es la forma de leer el valor actual.
- **Datos mock aislados**: viven en `data/mock_*_repository.dart` y en
  `core/constants/mock_data.dart`, claramente marcados. Se eliminarán al
  conectar Supabase.
- **Identidad de usuario**: el usuario actual se referencia por `id`
  (`kMockCurrentUserId = 'me'`), nunca por correo o nombre. En la Etapa 2 será
  el `id` de Supabase Auth.
- **Localización**: la app fuerza `es` y usa `flutter_localizations` +
  `initializeDateFormatting('es')`.

## Pendiente (etapas siguientes)

- Esquema PostgreSQL y RLS (Etapa 2).
- Autenticación real y perfil persistente (Etapa 2).
- Partidos, invitaciones y reglas de negocio en backend (Etapas 3-5).
- Notificaciones push (Etapa 6).
