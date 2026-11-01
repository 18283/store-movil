/// Modelos de Venta/Pago (CU22/23/27/28), espejo de
/// `app/modules/ventas/schemas.py`.
library;

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class ItemVenta {
  final int id;
  final int varianteId;
  final int? productoId;
  final String? producto;
  final String? talla;
  final String? color;
  final int cantidad;
  final double precioUnitario;
  // Precio sin promoción (null en ventas anteriores a las promociones).
  final double? precioOriginal;
  final double subtotal;
  // Sucursal de la que sale esta prenda (una compra puede salir de varias).
  final String? sucursal;

  ItemVenta({
    required this.id,
    required this.varianteId,
    this.productoId,
    required this.producto,
    required this.talla,
    required this.color,
    required this.cantidad,
    required this.precioUnitario,
    this.precioOriginal,
    required this.subtotal,
    this.sucursal,
  });

  factory ItemVenta.fromJson(Map<String, dynamic> json) => ItemVenta(
    id: json['id'] as int,
    varianteId: json['variante_id'] as int,
    productoId: json['producto_id'] as int?,
    producto: json['producto'] as String?,
    talla: json['talla'] as String?,
    color: json['color'] as String?,
    cantidad: json['cantidad'] as int,
    precioUnitario: _toDouble(json['precio_unitario']) ?? 0,
    precioOriginal: _toDouble(json['precio_original']),
    subtotal: _toDouble(json['subtotal']) ?? 0,
    sucursal: json['sucursal'] as String?,
  );
}

class Venta {
  final int id;
  final int sucursalId;
  final String? sucursal;
  final String? ciudad;
  // true si la compra sale de más de una sucursal ("Varias sucursales").
  final bool variasSucursales;
  // Si la compra nació de una reserva: se cobra en caja, no en línea.
  final int? reservaId;
  // Solo compras en línea: a dónde se envía (el delivery es externo).
  final String? direccionEntrega;
  final String? referenciaEntrega;
  final String estado; // PENDIENTE_PAGO | PAGADA | COMPLETADA | ANULADA
  final double total;
  final String fechaCreacion;
  final List<ItemVenta> items;

  Venta({
    required this.id,
    required this.sucursalId,
    required this.sucursal,
    required this.ciudad,
    this.variasSucursales = false,
    this.reservaId,
    this.direccionEntrega,
    this.referenciaEntrega,
    required this.estado,
    required this.total,
    required this.fechaCreacion,
    required this.items,
  });

  factory Venta.fromJson(Map<String, dynamic> json) => Venta(
    id: json['id'] as int,
    sucursalId: json['sucursal_id'] as int,
    sucursal: json['sucursal'] as String?,
    ciudad: json['ciudad'] as String?,
    variasSucursales: json['varias_sucursales'] as bool? ?? false,
    reservaId: json['reserva_id'] as int?,
    direccionEntrega: json['direccion_entrega'] as String?,
    referenciaEntrega: json['referencia_entrega'] as String?,
    estado: json['estado'] as String,
    total: _toDouble(json['total']) ?? 0,
    fechaCreacion: json['fecha_creacion'] as String,
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => ItemVenta.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Cuánto se descontó en la compra por promociones.
  double get ahorro => items.fold(
    0.0,
    (t, i) =>
        t +
        (i.precioOriginal != null
            ? (i.precioOriginal! - i.precioUnitario) * i.cantidad
            : 0),
  );

  Venta copyWithEstado(String nuevoEstado) => Venta(
    id: id,
    sucursalId: sucursalId,
    sucursal: sucursal,
    ciudad: ciudad,
    variasSucursales: variasSucursales,
    reservaId: reservaId,
    direccionEntrega: direccionEntrega,
    referenciaEntrega: referenciaEntrega,
    estado: nuevoEstado,
    total: total,
    fechaCreacion: fechaCreacion,
    items: items,
  );
}

class Pago {
  final int id;
  final int ventaId;
  final String metodo;
  final String estado;
  final double monto;
  final String? checkoutUrl;
  final String? qrDataUrl;

  Pago({
    required this.id,
    required this.ventaId,
    required this.metodo,
    required this.estado,
    required this.monto,
    required this.checkoutUrl,
    required this.qrDataUrl,
  });

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
    id: json['id'] as int,
    ventaId: json['venta_id'] as int,
    metodo: json['metodo'] as String,
    estado: json['estado'] as String,
    monto: _toDouble(json['monto']) ?? 0,
    checkoutUrl: json['checkout_url'] as String?,
    qrDataUrl: json['qr_data_url'] as String?,
  );
}

class EstadoPagoInfo {
  final String ventaEstado;
  final String? pagoEstado;

  EstadoPagoInfo({required this.ventaEstado, required this.pagoEstado});

  factory EstadoPagoInfo.fromJson(Map<String, dynamic> json) =>
      EstadoPagoInfo(
        ventaEstado: json['venta_estado'] as String,
        pagoEstado: json['pago_estado'] as String?,
      );
}

const etiquetaEstadoVenta = {
  'PENDIENTE_PAGO': 'Pendiente de pago',
  'PAGADA': 'Pagada',
  'COMPLETADA': 'Completada',
  'ANULADA': 'Anulada',
};
