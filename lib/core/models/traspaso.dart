/// CU24 — Solicitar traspaso de prenda (código anterior: CU61).
/// Modelos que reflejan el diagrama de robustez y los esquemas del backend FastAPI
/// (`app/modules/traspasos/schemas.py`).
library;

class SucursalTraspaso {
  final int id;
  final String nombre;
  final String ciudad;

  SucursalTraspaso({
    required this.id,
    required this.nombre,
    required this.ciudad,
  });

  factory SucursalTraspaso.fromJson(Map<String, dynamic> json) =>
      SucursalTraspaso(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        ciudad: json['ciudad'] as String,
      );
}

/// Mensajes 2-9 del diagrama: GET /traspasos/opciones.
class OpcionesTraspaso {
  final String rol;
  final int? clienteId;
  final int? sucursalAsignadaId;
  final List<SucursalTraspaso> sucursales;
  final int? destinoPermitidoId;

  OpcionesTraspaso({
    required this.rol,
    this.clienteId,
    this.sucursalAsignadaId,
    required this.sucursales,
    this.destinoPermitidoId,
  });

  factory OpcionesTraspaso.fromJson(Map<String, dynamic> json) {
    final lista = (json['sucursales'] as List<dynamic>? ?? [])
        .map((e) => SucursalTraspaso.fromJson(e as Map<String, dynamic>))
        .toList();
    return OpcionesTraspaso(
      rol: json['rol'] as String? ?? 'Cliente',
      clienteId: json['cliente_id'] as int?,
      sucursalAsignadaId: json['sucursal_asignada_id'] as int?,
      sucursales: lista,
      destinoPermitidoId: json['destino_permitido_id'] as int?,
    );
  }
}

/// Mensajes 12-19 del diagrama: Fila de GET /traspasos/variantes?q=...
/// Cada fila contiene la variante y una sucursal de origen con stock.
class VarianteConStock {
  final int varianteId;
  final int? productoId;
  final String producto;
  final String? sku;
  final String? talla;
  final String? color;
  final String? colorHex;
  final int origenId;
  final String origen;
  final String ciudad;
  final int cantidadDisponible;

  VarianteConStock({
    required this.varianteId,
    this.productoId,
    required this.producto,
    this.sku,
    this.talla,
    this.color,
    this.colorHex,
    required this.origenId,
    required this.origen,
    required this.ciudad,
    required this.cantidadDisponible,
  });

  factory VarianteConStock.fromJson(Map<String, dynamic> json) =>
      VarianteConStock(
        varianteId: json['variante_id'] as int,
        productoId: json['producto_id'] as int?,
        producto: json['producto'] as String? ?? '',
        sku: json['sku'] as String?,
        talla: json['talla'] as String?,
        color: json['color'] as String?,
        colorHex: json['color_hex'] as String?,
        origenId: json['origen_id'] as int,
        origen: json['origen'] as String? ?? '',
        ciudad: json['ciudad'] as String? ?? '',
        cantidadDisponible: json['cantidad_disponible'] as int? ?? 0,
      );
}

/// Mensajes 22-39 del diagrama: Respuesta de POST /traspasos o GET /traspasos/{codigo}.
class SolicitudTraspaso {
  final int? id;
  final String codigo;
  final String estado; // PENDIENTE
  final String? resumen;
  final int? varianteId;
  final String? variante;
  final String? producto;
  final String? sku;
  final String? talla;
  final String? color;
  final String? colorHex;
  final String? imagenUrl;
  final int? origenId;
  final String? origen;
  final String? ciudadOrigen;
  final int? destinoId;
  final String? destino;
  final String? ciudadDestino;
  final int cantidad;
  final String? motivo;
  final String? solicitante;
  final String? solicitanteRol;
  final String? fechaSolicitud;
  final int? stockOrigen;
  final int? stockDestino;
  final bool requiereConfirmacion;
  final String? mensaje;

  SolicitudTraspaso({
    this.id,
    required this.codigo,
    required this.estado,
    this.resumen,
    this.varianteId,
    this.variante,
    this.producto,
    this.sku,
    this.talla,
    this.color,
    this.colorHex,
    this.imagenUrl,
    this.origenId,
    this.origen,
    this.ciudadOrigen,
    this.destinoId,
    this.destino,
    this.ciudadDestino,
    required this.cantidad,
    this.motivo,
    this.solicitante,
    this.solicitanteRol,
    this.fechaSolicitud,
    this.stockOrigen,
    this.stockDestino,
    this.requiereConfirmacion = false,
    this.mensaje,
  });

  factory SolicitudTraspaso.fromJson(Map<String, dynamic> json) =>
      SolicitudTraspaso(
        id: json['id'] as int?,
        codigo: json['codigo'] as String? ?? '',
        estado: json['estado'] as String? ?? 'PENDIENTE',
        resumen: json['resumen'] as String?,
        varianteId: json['variante_id'] as int?,
        variante: json['variante'] as String?,
        producto: json['producto'] as String?,
        sku: json['sku'] as String?,
        talla: json['talla'] as String?,
        color: json['color'] as String?,
        colorHex: json['color_hex'] as String?,
        imagenUrl: json['imagen_url'] as String?,
        origenId: json['origen_id'] as int?,
        origen: json['origen'] as String?,
        ciudadOrigen: json['ciudad_origen'] as String?,
        destinoId: json['destino_id'] as int?,
        destino: json['destino'] as String?,
        ciudadDestino: json['ciudad_destino'] as String?,
        cantidad: json['cantidad'] as int? ?? 1,
        motivo: json['motivo'] as String?,
        solicitante: json['solicitante'] as String?,
        solicitanteRol: json['solicitante_rol'] as String?,
        fechaSolicitud: json['fecha_solicitud'] as String?,
        stockOrigen: json['stock_origen'] as int?,
        stockDestino: json['stock_destino'] as int?,
        requiereConfirmacion: json['requiere_confirmacion'] as bool? ?? false,
        mensaje: json['mensaje'] as String?,
      );
}
