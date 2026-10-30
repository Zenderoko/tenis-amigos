import 'package:intl/intl.dart';

/// Formato de fechas y horas en español.
///
/// `intl` necesita que se inicialicen los datos de localización (ver
/// `main.dart` con `initializeDateFormatting('es')`).
abstract final class AppDateFormatters {
  static const String _locale = 'es';

  /// "lunes", "martes", ... (en minúscula, como devuelve `intl`).
  static String weekdayLong(DateTime date) =>
      DateFormat('EEEE', _locale).format(date);

  /// "lunes 5 de mayo".
  static String weekdayDayMonth(DateTime date) =>
      DateFormat("EEEE d 'de' MMMM", _locale).format(date);

  /// "5 de mayo".
  static String dayMonth(DateTime date) =>
      DateFormat("d 'de' MMMM", _locale).format(date);

  /// "5 may".
  static String dayMonthShort(DateTime date) =>
      DateFormat('d MMM', _locale).format(date);

  /// "lunes 5 de mayo de 2026".
  static String fullDate(DateTime date) =>
      DateFormat("EEEE d 'de' MMMM 'de' y", _locale).format(date);

  /// "mayo de 2026".
  static String monthYear(DateTime date) =>
      DateFormat("MMMM 'de' y", _locale).format(date);

  /// "19:30".
  static String time(DateTime date) =>
      DateFormat('HH:mm', _locale).format(date);

  /// "19:30 – 21:00" a partir de la hora de inicio y la duración.
  static String timeRange(DateTime start, int durationMinutes) {
    final DateTime end = start.add(Duration(minutes: durationMinutes));
    return '${time(start)} – ${time(end)}';
  }

  /// Convierte la primera letra en mayúscula ("lunes" → "Lunes").
  static String capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
