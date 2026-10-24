int _entero(dynamic valor, String campo) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  final convertido = int.tryParse(valor?.toString() ?? '');
  if (convertido != null) return convertido;
  throw FormatException('El campo $campo no contiene un número válido.');
}

double? _decimalOpcional(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}

class VarianteOffline {
  final int id;
  final String sku;
  final String talla;
  final String color;
  final double? precio;
  final String? imagenUrl;
  final int cantidadDisponible;
  final int cantidadReservada;

  const VarianteOffline({
    required this.id,
    required this.sku,
    required this.talla,
    required this.color,
    required this.precio,
    required this.imagenUrl,
    required this.cantidadDisponible,
    required this.cantidadReservada,
  });

  factory VarianteOffline.fromJson(Map<String, dynamic> json) =>
      VarianteOffline(
        id: _entero(json['id'], 'variante.id'),
        sku: json['sku'] as String,
        talla: json['talla'] as String,
        color: json['color'] as String,
        precio: _decimalOpcional(json['precio']),
        imagenUrl: json['imagen_url'] as String?,
        cantidadDisponible: _entero(
          json['cantidad_disponible'],
          'cantidad_disponible',
        ),
        cantidadReservada: _entero(
          json['cantidad_reservada'],
          'cantidad_reservada',
        ),
      );
}

class ProductoOffline {
  final int id;
  final String nombre;
  final String categoria;
  final String? descripcion;
  final double? precioBase;
  final String? imagenUrl;
  final List<VarianteOffline> variantes;

  const ProductoOffline({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.precioBase,
    required this.imagenUrl,
    required this.variantes,
  });

  factory ProductoOffline.fromJson(Map<String, dynamic> json) =>
      ProductoOffline(
        id: _entero(json['id'], 'producto.id'),
        nombre: json['nombre'] as String,
        categoria: json['categoria'] as String,
        descripcion: json['descripcion'] as String?,
        precioBase: _decimalOpcional(json['precio_base']),
        imagenUrl: json['imagen_url'] as String?,
        variantes: (json['variantes'] as List)
            .map((e) => VarianteOffline.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DatosOffline {
  final int schemaVersion;
  final String versionDatos;
  final int empresaId;
  final int sucursalId;
  final String sucursalNombre;
  final DateTime generadoEn;
  final DateTime guardadoEn;
  final List<ProductoOffline> productos;

  const DatosOffline({
    required this.schemaVersion,
    required this.versionDatos,
    required this.empresaId,
    required this.sucursalId,
    required this.sucursalNombre,
    required this.generadoEn,
    required this.guardadoEn,
    required this.productos,
  });

  factory DatosOffline.fromJson(
    Map<String, dynamic> json, {
    DateTime? guardadoEn,
  }) => DatosOffline(
    schemaVersion: _entero(json['schema_version'], 'schema_version'),
    versionDatos: json['version_datos'] as String,
    empresaId: _entero(json['empresa_id'], 'empresa_id'),
    sucursalId: _entero(json['sucursal_id'], 'sucursal_id'),
    sucursalNombre: json['sucursal_nombre'] as String,
    generadoEn: DateTime.parse(json['generado_en'] as String),
    guardadoEn: guardadoEn ?? DateTime.now(),
    productos: (json['productos'] as List)
        .map((e) => ProductoOffline.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  int get totalVariantes => productos.fold(0, (n, p) => n + p.variantes.length);
}

class VarianteOfflineVista {
  final ProductoOffline producto;
  final VarianteOffline variante;
  const VarianteOfflineVista(this.producto, this.variante);
}

List<VarianteOfflineVista> filtrarDatosOffline(
  DatosOffline? datos, {
  String busqueda = '',
  String talla = '',
  String color = '',
}) {
  if (datos == null) return [];
  final q = busqueda.trim().toLowerCase();
  return [
    for (final producto in datos.productos)
      for (final variante in producto.variantes)
        if ((q.isEmpty ||
                '${producto.nombre} ${producto.categoria} ${variante.sku}'
                    .toLowerCase()
                    .contains(q)) &&
            (talla.isEmpty || variante.talla == talla) &&
            (color.isEmpty || variante.color == color))
          VarianteOfflineVista(producto, variante),
  ];
}
