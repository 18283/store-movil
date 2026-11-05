/// Error de la API ya traducido a un mensaje legible para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Código estable de error de negocio (p. ej. `STOCK_INSUFICIENTE`).
  /// El backend de CU24 lo manda en el nivel superior o dentro de `detail`.
  final String? codigo;

  /// Cuerpo JSON completo de la respuesta de error, para leer datos extra
  /// como `stock_destino`, `codigo_solicitud` o `requiere_confirmacion`.
  final Map<String, dynamic>? data;

  ApiException(
    this.message, {
    this.statusCode,
    this.codigo,
    this.data,
  });

  /// Datos del error. Si `detail` es un objeto (algunos endpoints lo usan para
  /// devolver códigos y datos de negocio) se devuelve ese objeto; si no, el
  /// cuerpo completo.
  Map<String, dynamic>? get detalle {
    final detail = data?['detail'];
    if (detail is Map<String, dynamic>) return detail;
    return data;
  }

  @override
  String toString() => message;
}
