import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Conversión entre UTC y la zona horaria IANA del partido.
///
/// Los partidos se guardan en UTC y se muestran en su zona horaria. Así el
/// horario de verano se calcula con la base de datos IANA y no a mano.
abstract final class MatchTime {
  static bool _initialized = false;

  /// Carga la base IANA una sola vez. `main` la llama al arrancar y el resto de
  /// conversiones la aseguran para pruebas u otras entradas.
  static void initialize() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location locationFor(String timezone) {
    initialize();
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.getLocation('America/Santiago');
    }
  }

  /// Convierte un instante UTC a la zona horaria del partido.
  static DateTime inZone(DateTime instant, String timezone) {
    return tz.TZDateTime.from(instant.toUtc(), locationFor(timezone));
  }

  /// Convierte una fecha y hora local de la zona del partido a UTC.
  static DateTime toUtc({required DateTime local, required String timezone}) {
    final tz.Location location = locationFor(timezone);
    return tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ).toUtc();
  }

  /// Fecha y hora actuales en la zona horaria indicada.
  static DateTime nowIn(String timezone) =>
      tz.TZDateTime.now(locationFor(timezone));
}
