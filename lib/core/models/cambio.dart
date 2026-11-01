/// CU17-CU23 — cambios y devoluciones (solo lado cliente en el móvil:
/// CU18 solicitar, CU23 consultar historial). Espejo de
/// `app/modules/cambios/schemas.py`.
library;

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class Solicitud {
  final int id;
  final int ventaId;
  final int ventaDetalleId;
  final String? sucursal;
  final String tipo; // CAMBIO | DEVOLUCION
  final String? producto;
  final int varianteDevueltaId;
  final String? varianteDevuelta;
  final int cantidad;
  final int? varianteNuevaId;
  final String? varianteNueva;
  final String estado; // SOLICITADO | RECIBIDO | RESUELTO | CANCELADO
  final String fechaSolicitud;
  final String fechaLimite;
  final double? diferencia;
  final String? formaPagoDiferencia;

  Solicitud({
    required this.id,
    required this.ventaId,
    required this.ventaDetalleId,
    required this.sucursal,
    required this.tipo,
    required this.producto,
    required this.varianteDevueltaId,
    required this.varianteDevuelta,
    required this.cantidad,
    required this.varianteNuevaId,
    required this.varianteNueva,
    required this.estado,
    required this.fechaSolicitud,
    required this.fechaLimite,
    required this.diferencia,
    required this.formaPagoDiferencia,
  });

  factory Solicitud.fromJson(Map<String, dynamic> json) => Solicitud(
    id: json['id'] as int,
    ventaId: json['venta_id'] as int,
    ventaDetalleId: json['venta_detalle_id'] as int,
    sucursal: json['sucursal'] as String?,
    tipo: json['tipo'] as String,
    producto: json['producto'] as String?,
    varianteDevueltaId: json['variante_devuelta_id'] as int,
    varianteDevuelta: json['variante_devuelta'] as String?,
    cantidad: json['cantidad'] as int,
    varianteNuevaId: json['variante_nueva_id'] as int?,
    varianteNueva: json['variante_nueva'] as String?,
    estado: json['estado'] as String,
    fechaSolicitud: json['fecha_solicitud'] as String,
    fechaLimite: json['fecha_limite'] as String,
    diferencia: _toDouble(json['diferencia']),
    formaPagoDiferencia: json['forma_pago_diferencia'] as String?,
  );
}

const etiquetaEstadoSolicitud = {
  'SOLICITADO': 'Solicitado — llevá la prenda a la sucursal',
  'RECIBIDO': 'Prenda recibida, en proceso',
  'RESUELTO': 'Resuelto',
  'CANCELADO': 'Cancelado',
};
