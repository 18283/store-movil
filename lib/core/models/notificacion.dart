/// CU29 / CU35 — Consultar notificaciones de traspaso.
/// Espejo de lo que devuelve el backend (`/notificaciones`).
class Notificacion {
  final int id;
  final String mensaje;
  final String tipo; // 'success' | 'info' | 'warning' | 'error'
  final bool leida;
  final String? modulo;
  final String? codigoTraspaso;
  final DateTime fecha;

  Notificacion({
    required this.id,
    required this.mensaje,
    this.tipo = 'info',
    this.leida = false,
    this.modulo,
    this.codigoTraspaso,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  Notificacion copyWith({bool? leida}) => Notificacion(
        id: id,
        mensaje: mensaje,
        tipo: tipo,
        leida: leida ?? this.leida,
        modulo: modulo,
        codigoTraspaso: codigoTraspaso,
        fecha: fecha,
      );

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: _int(json, ['id']) ?? 0,
      mensaje: _str(json, ['mensaje', 'message', 'titulo', 'contenido', 'texto', 'descripcion']) ?? 'Notificación',
      tipo: _str(json, ['tipo', 'type']) ?? 'info',
      leida: _bool(json, ['leida', 'leída', 'is_leida', 'leido', 'read']),
      modulo: _str(json, ['modulo', 'module']),
      codigoTraspaso: _str(json, [
        'codigo_traspaso',
        'codigoTraspaso',
        'codigo_solicitud',
        'traspaso_codigo',
      ]),
      fecha: _fecha(json),
    );
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _str(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  static bool _bool(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v is bool) return v;
      if (v is num) return v == 1;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'sí' || s == 'si') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
      }
    }
    return false;
  }

  static DateTime? _fecha(Map<String, dynamic> json) {
    final v = _str(json, ['fecha', 'fecha_creacion', 'fechaCreacion', 'created_at', 'creada_en']);
    if (v == null) return null;
    return DateTime.tryParse(v);
  }
}
