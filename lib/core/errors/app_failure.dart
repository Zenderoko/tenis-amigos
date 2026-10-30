/// Error controlado de la aplicación.
///
/// La capa de presentación solo muestra [message]; los detalles técnicos se
/// registran en logs de depuración cuando corresponde.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
