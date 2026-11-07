/// CU36 — Consultar alertas y sugerencias de reposición.
class AlertaReposicion {
  final int? id;
  final int varianteId;
  final String producto;
  final String? sku;
  final String? talla;
  final String? color;
  final int sucursalId;
  final String sucursalNombre;
  final int stockActual;
  final int stockMinimo;
  final int cantidadSugerida;
  final String tipoAlerta; // 'STOCK_BAJO', 'AGOTADO', 'SUGERENCIA'
  final String? fechaAlerta;

  AlertaReposicion({
    this.id,
    required this.varianteId,
    required this.producto,
    this.sku,
    this.talla,
    this.color,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.stockActual,
    required this.stockMinimo,
    required this.cantidadSugerida,
    required this.tipoAlerta,
    this.fechaAlerta,
  });

  factory AlertaReposicion.fromJson(Map<String, dynamic> json) => AlertaReposicion(
        id: json['id'] as int?,
        varianteId: json['variante_id'] as int? ?? json['varianteId'] as int? ?? 0,
        producto: json['producto'] as String? ?? 'Producto',
        sku: json['sku'] as String?,
        talla: json['talla'] as String?,
        color: json['color'] as String?,
        sucursalId: json['sucursal_id'] as int? ?? json['sucursalId'] as int? ?? 0,
        sucursalNombre: json['sucursal_nombre'] as String? ?? json['sucursal'] as String? ?? 'Sucursal',
        stockActual: json['stock_actual'] as int? ?? json['stockActual'] as int? ?? 0,
        stockMinimo: json['stock_minimo'] as int? ?? json['stockMinimo'] as int? ?? 0,
        cantidadSugerida: json['cantidad_sugerida'] as int? ?? json['cantidadSugerida'] as int? ?? 1,
        tipoAlerta: json['tipo_alerta'] as String? ?? json['tipoAlerta'] as String? ?? 'STOCK_BAJO',
        fechaAlerta: json['fecha_alerta'] as String? ?? json['fechaAlerta'] as String?,
      );
}
