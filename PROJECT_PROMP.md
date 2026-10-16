# Proyecto: App móvil para organizar partidos de tenis

## 1. Rol y forma de trabajo

Actúa como un desarrollador senior especializado en Flutter, Dart, Supabase, PostgreSQL, diseño de aplicaciones móviles y arquitectura de software escalable.

Tu tarea es ayudarme a desarrollar una aplicación móvil para organizar partidos de tenis entre amigos.

Soy un desarrollador principiante. Trabajo en Windows, utilizo Visual Studio Code y OpenCode. Necesito que me expliques los conceptos y las decisiones técnicas con claridad, pero que también escribas código de calidad profesional.

**Reglas de trabajo:**

- Antes de modificar archivos, inspecciona el proyecto y el entorno disponible.
- No supongas que Flutter, Dart, Git u otras herramientas están instaladas. Comprueba su disponibilidad.
- Si el proyecto ya contiene código, analízalo antes de reemplazarlo.
- Trabaja por etapas pequeñas y verificables. No intentes desarrollar toda la aplicación en una única ejecución.
- Antes de implementar cada etapa, explica brevemente qué construirás y qué archivos probablemente modificarás.
- Después de implementarla, ejecuta las comprobaciones y pruebas que correspondan.
- Si algo falla, diagnostica el problema y corrígelo antes de avanzar.
- No inventes resultados de comandos, pruebas, configuraciones ni servicios.
- Utiliza versiones estables y compatibles de las dependencias. Verifica la versión disponible en el entorno antes de elegirla.
- No agregues dependencias innecesarias.
- No introduzcas funcionalidades fuera del alcance acordado sin consultarme.
- No continúes automáticamente con la siguiente etapa. Al terminar una etapa, resume lo realizado y espera mi aprobación para continuar.
- Dame instrucciones concretas para ejecutar los comandos en PowerShell desde VS Code.
- Si necesitas que cree una cuenta, configure una consola externa o proporcione credenciales, explícame el procedimiento y espera a que esté listo.

## 2. Descripción del producto

Crear una app móvil en español para que grupos de amigos puedan organizar partidos de tenis.

Los usuarios deben poder:

- Registrarse e iniciar sesión.
- Crear un perfil básico.
- Agregar amigos e invitarlos a la aplicación.
- Crear partidos de singles y dobles.
- Seleccionar fecha, hora, duración, lugar y participantes.
- Enviar invitaciones y recibir respuestas.
- Consultar sus partidos en una lista y en un calendario.
- Cancelar partidos.
- Proponer cambios de fecha y hora.
- Aceptar o rechazar propuestas de reprogramación.
- Consultar el estado actualizado del partido.
- Recibir notificaciones de invitaciones, cambios y recordatorios.
- Consultar un historial básico de partidos.

La primera versión estará orientada a grupos cerrados de amigos. No es necesario que un usuario pueda encontrar rivales desconocidos.

El nombre de la app es provisional: **TenisAmigos**. Mantén el nombre y otros datos de marca fácilmente modificables.

## 3. Tecnologías

Utiliza este stack como base:

- Flutter y Dart para Android y iOS.
- Supabase para autenticación, base de datos PostgreSQL y backend.
- Riverpod para la gestión del estado, si resulta compatible con las versiones seleccionadas.
- GoRouter para navegación.
- Supabase Flutter SDK para comunicarse con Supabase.
- Firebase Cloud Messaging para notificaciones push cuando corresponda.
- Git para control de versiones.

Puedes proponer un cambio tecnológico si encuentras una incompatibilidad importante, pero explícame el motivo antes de cambiar el stack.

No implementes microservicios. La primera versión debe ser un monolito móvil con backend administrado y módulos de negocio claramente separados.

## 4. Arquitectura del código

Organiza el proyecto por funcionalidades, manteniendo separadas las responsabilidades.

Una estructura orientativa:

lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    errors/
    utils/
    widgets/
  features/
    auth/
      data/
      domain/
      presentation/
    profile/
      data/
      domain/
      presentation/
    friends/
      data/
      domain/
      presentation/
    matches/
      data/
      domain/
      presentation/
    calendar/
      presentation/
    notifications/
      data/
      domain/
      presentation/
  main.dart

Adapta la estructura cuando sea necesario. No crees carpetas o clases vacías solo para aparentar una arquitectura.

Cada funcionalidad debe tener responsabilidades claras:

- Presentation: pantallas, widgets y estado de interfaz.
- Domain: modelos y reglas de negocio cuando su complejidad lo justifique.
- Data: repositorios y acceso a Supabase.

La interfaz no debe ejecutar directamente consultas SQL ni contener toda la lógica de negocio.

Utiliza repositorios para que las pantallas no dependan directamente de los detalles de la base de datos.

Evita sobreingeniería: crea abstracciones cuando aporten claridad, testabilidad o flexibilidad real.

## 5. Diseño de la interfaz

La app debe tener una interfaz moderna, amigable, limpia y deportiva.

Requisitos:

- Todo el contenido visible estará en español.
- Diseño mobile-first.
- Buena legibilidad y jerarquía visual.
- Componentes reutilizables.
- Estados de carga, error, vacío y éxito.
- Formularios con validaciones y mensajes claros.
- Accesibilidad básica: tamaños de texto adecuados, contraste y controles cómodos.
- Diseño adaptable a diferentes tamaños de pantalla.

Propón una identidad visual inspirada en el tenis, sin recargar la interfaz con elementos decorativos.

La navegación principal tendrá cuatro secciones:

1. Inicio: próximos partidos e invitaciones pendientes.
2. Calendario: vista semanal o mensual.
3. Amigos: contactos dentro de la app.
4. Perfil: información personal y configuración.

La pantalla inicial debe permitir crear un partido rápidamente.

Diseña primero las pantallas esenciales y utiliza datos ficticios solo para prototipos visuales. No presentes datos ficticios como información real del backend.

## 6. Autenticación y perfil

Implementa registro e inicio de sesión con:

- Correo electrónico y contraseña.
- Inicio de sesión mediante Google OAuth.
- Cierre de sesión.
- Persistencia de sesión.
- Manejo de errores de autenticación.
- Recuperación de contraseña mediante correo, cuando esté configurada.

La autenticación debe utilizar Supabase Auth.

Google OAuth requiere configuración externa. No inventes credenciales ni simules que la autenticación real funciona sin haberla configurado y probado.

Explícame paso a paso cómo configurar:

1. El proyecto Supabase.
2. El proveedor Google en Supabase.
3. Las credenciales OAuth en Google Cloud.
4. Las URLs de retorno y los deep links necesarios para Flutter.
5. Las variables de configuración locales.

No incluyas secretos en el código, repositorio Git, archivos de ejemplo ni logs.

Crea un archivo `.env.example` o una configuración equivalente que indique qué valores necesita el proyecto. No inventes claves reales.

Después del registro, el usuario podrá completar:

- Nombre visible.
- Foto de perfil opcional.
- Nivel de tenis opcional.
- Mano dominante opcional.

No solicites datos innecesarios. El nombre visible debe poder editarse.

La identidad interna del usuario debe depender de su ID de Supabase Auth, no de su nombre ni de su correo.

## 7. Modelo de datos inicial

Diseña un esquema PostgreSQL normalizado y adecuado para Supabase.

Entidades principales:

### profiles

- id: UUID asociado al usuario autenticado.
- display_name.
- avatar_url opcional.
- tennis_level opcional.
- created_at.
- updated_at.

### friendships

- id.
- user_id.
- friend_id.
- status.
- created_at.

Estados sugeridos: pending, accepted, rejected.

Define cómo impedir amistades duplicadas y solicitudes inconsistentes.

### matches

- id.
- organizer_id.
- format: singles o doubles.
- starts_at.
- timezone.
- duration_minutes.
- location_name.
- location_details opcionales.
- status.
- created_at.
- updated_at.
- version, si se utiliza para controlar actualizaciones concurrentes.

Estados iniciales sugeridos:

- awaiting_players.
- confirmed.
- cancelled.
- completed.

Define claramente qué significa cada estado y cuándo se aplica.

### match_participants

- id.
- match_id.
- user_id.
- role.
- response.
- invited_at.
- responded_at.

Roles: organizer, player.

Respuestas: invited, accepted, declined, withdrawn.

Evita que un usuario aparezca dos veces como participante del mismo partido.

### match_proposals

Registra propuestas de reprogramación:

- id.
- match_id.
- proposed_by.
- proposed_starts_at.
- proposed_timezone.
- status.
- created_at.
- resolved_at.

Define estados como pending, accepted, rejected y superseded.

### match_events

Historial de eventos relevantes:

- creación.
- invitación.
- respuesta.
- cambio de horario propuesto.
- cambio de horario aceptado.
- cancelación.
- finalización.

No guardes datos sensibles innecesarios en el historial.

Implementa el esquema mediante migraciones SQL versionadas. No dependas exclusivamente de crear tablas manualmente desde el panel de Supabase.

## 8. Reglas de negocio de los partidos

Antes de implementar las pantallas de partidos, define y documenta las reglas.

Como mínimo:

- Singles admite dos jugadores.
- Dobles admite cuatro jugadores.
- El organizador ocupa una plaza.
- Un usuario no puede aceptar una invitación si el partido ya está cancelado.
- Un partido no puede estar confirmado si no cumple las condiciones definidas de participantes.
- El organizador puede cancelar el partido.
- Los participantes pueden rechazar una invitación o retirarse, según las reglas definidas.
- Los cambios de fecha deben quedar registrados.
- Una propuesta de reprogramación no debe cambiar la fecha oficial hasta que se apruebe.
- No puede haber dos propuestas activas incompatibles para un mismo partido.
- Las operaciones que cambian el estado deben validarse en el backend.
- Las operaciones concurrentes deben protegerse contra actualizaciones inconsistentes.

Para la primera versión, define una política sencilla de reprogramación. Por ejemplo, el organizador propone el cambio y los participantes deben aceptarlo. Si el modelo resulta demasiado complejo, propón una alternativa más simple y explícala antes de implementarla.

No integres reservas reales de canchas, pagos, rankings ni torneos en el MVP.

## 9. Seguridad

Utiliza Row Level Security (RLS) en las tablas de Supabase.

Diseña políticas para garantizar que:

- Los usuarios solo puedan modificar su propio perfil.
- Solo los usuarios autorizados puedan consultar los detalles de un partido.
- Solo el organizador pueda realizar las operaciones reservadas al organizador.
- Cada participante solo pueda modificar su propia respuesta, dentro de las reglas.
- Un usuario no pueda agregarse arbitrariamente a partidos privados.
- Los datos privados no queden expuestos por consultas directas a la API.

No utilices la clave service_role dentro de Flutter.

Si una operación necesita permisos elevados, debe ejecutarse en un entorno de servidor protegido, no en el cliente móvil.

Incluye pruebas o verificaciones de seguridad para las políticas principales.

## 10. Calendario y fechas

El calendario debe mostrar partidos próximos y permitir abrir su detalle.

Incluye:

- Vista semanal o mensual.
- Indicadores visuales para invitaciones pendientes, partidos confirmados y cancelados.
- Acceso al detalle de cada partido.
- Formato de fecha y hora en español.
- Validación para impedir horarios inválidos o fechas pasadas al crear un partido.

Almacena instantes de forma consistente, preferiblemente UTC, y conserva la zona horaria necesaria para representar correctamente el horario local del partido.

No calcules manualmente el horario de verano de Chile. Utiliza una solución de zonas horarias apropiada.

No implementes inicialmente sincronización bidireccional con Google Calendar o calendarios del sistema.

## 11. Notificaciones

Implementa primero las notificaciones necesarias para que el MVP sea útil.

Eventos:

- Nueva invitación.
- Invitación aceptada o rechazada.
- Propuesta de reprogramación.
- Cambio de horario aprobado.
- Cancelación.
- Recordatorio previo al partido.

Separa la lógica de notificaciones de la lógica de partidos.

Utiliza un mecanismo de backend que evite notificaciones duplicadas cuando una operación se reintenta.

Si la configuración de Firebase requiere credenciales o pasos externos, explícame cómo realizarlos.

No simules que las notificaciones push están funcionando si todavía no se han configurado. Puedes desarrollar inicialmente estados y avisos dentro de la app, dejando el servicio push preparado para una etapa posterior.

## 12. Pruebas y calidad

Escribe pruebas acordes con la etapa:

- Unit tests para reglas de negocio y validaciones.
- Pruebas de repositorios cuando sea posible.
- Widget tests para pantallas y estados importantes.
- Verificación de navegación.
- Pruebas de permisos y políticas RLS para operaciones sensibles.

Antes de terminar cada etapa:

- Ejecuta `flutter analyze`.
- Ejecuta las pruebas relevantes.
- Comprueba que la aplicación compile en el entorno disponible.
- Revisa que no se hayan filtrado secretos.
- Corrige los problemas detectados.

No afirmes que una prueba pasó si no la ejecutaste.

## 13. Etapas de desarrollo

Trabaja en este orden:

### Etapa 0 — Preparación y planificación

- Inspeccionar el entorno Windows.
- Verificar Flutter, Dart, Git y los dispositivos disponibles.
- Revisar la estructura del proyecto.
- Proponer la estructura y el plan de trabajo.
- Identificar configuraciones externas necesarias.

No desarrolles funcionalidades todavía.

### Etapa 1 — Esqueleto de la app

- Crear o preparar el proyecto Flutter.
- Configurar navegación.
- Crear tema visual.
- Construir las pantallas principales con navegación funcional.
- Añadir estados de carga, vacío y error donde corresponda.

### Etapa 2 — Supabase y autenticación

- Configurar Supabase.
- Implementar registro por correo.
- Implementar login por correo.
- Preparar Google OAuth.
- Implementar perfil básico y persistencia de sesión.

### Etapa 3 — Amigos

- Solicitudes de amistad.
- Aceptar y rechazar solicitudes.
- Listado de amigos.
- Invitación a un amigo mediante un enlace, si resulta viable en esta etapa.

### Etapa 4 — Partidos

- Crear partidos.
- Seleccionar modalidad, fecha, hora, lugar y jugadores.
- Enviar invitaciones.
- Responder invitaciones.
- Consultar detalles y estado del partido.

### Etapa 5 — Calendario y reprogramación

- Calendario de partidos.
- Cancelación.
- Propuestas de reprogramación.
- Aprobación y rechazo de cambios.
- Historial de eventos.

### Etapa 6 — Notificaciones

- Avisos dentro de la app.
- Configuración de push.
- Recordatorios.
- Prevención de notificaciones duplicadas.

### Etapa 7 — Validación del MVP

- Pruebas funcionales.
- Revisión de seguridad.
- Corrección de errores.
- Prueba con un grupo pequeño de usuarios.
- Documentación para ejecutar y mantener el proyecto.

No avances de etapa sin mi aprobación.

## 14. Documentación del proyecto

Mantén actualizados:

- `README.md`: descripción y cómo ejecutar el proyecto.
- `docs/architecture.md`: arquitectura y decisiones.
- `docs/business-rules.md`: reglas de los partidos.
- `docs/setup-supabase.md`: configuración de Supabase y OAuth.
- `docs/development-roadmap.md`: etapas y estado del proyecto.

Documenta las decisiones importantes y sus motivos. No generes documentación extensa que no corresponda al código real.

## 15. Primera tarea

Comienza ahora con la **Etapa 0: preparación y planificación**.

Primero inspecciona mi entorno y el contenido del directorio actual.

Indícame:

1. Qué herramientas están instaladas y cuáles faltan.
2. Si el directorio ya contiene un proyecto.
3. Qué configuración necesito preparar.
4. Qué pasos concretos debo ejecutar en PowerShell.
5. Qué construiremos en la primera etapa.

No implementes todavía toda la app. Espera a que te confirme que podemos comenzar la Etapa 1.
