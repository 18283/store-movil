import 'package:flutter_test/flutter_test.dart';
import 'package:store_movil/core/offline/offline_models.dart';

void main() {
  test('filtra el catálogo guardado sin consultar el servidor', () {
    final datos = DatosOffline.fromJson({
      'schema_version': 1,
      'version_datos': 'test',
      'empresa_id': 1,
      'sucursal_id': 2,
      'sucursal_nombre': 'Centro',
      'generado_en': '2026-10-23T10:00:00Z',
      'productos': [
        {
          'id': 1,
          'nombre': 'Polera básica',
          'categoria': 'Poleras',
          'descripcion': null,
          'precio_base': 80,
          'imagen_url': null,
          'variantes': [
            {
              'id': 3,
              'sku': 'POL-M-NEG',
              'talla': 'M',
              'color': 'Negro',
              'precio': 85,
              'imagen_url': null,
              'cantidad_disponible': 4,
              'cantidad_reservada': 1,
            },
          ],
        },
      ],
    });
    expect(
      filtrarDatosOffline(datos, busqueda: 'polera', talla: 'M'),
      hasLength(1),
    );
    expect(filtrarDatosOffline(datos, color: 'Rojo'), isEmpty);
  });

  test('acepta precios y cantidades numéricas enviados como texto', () {
    final datos = DatosOffline.fromJson({
      'schema_version': '1',
      'version_datos': 'test-string-values',
      'empresa_id': '7',
      'sucursal_id': '9',
      'sucursal_nombre': 'Sucursal principal',
      'generado_en': '2026-10-24T10:00:00Z',
      'productos': [
        {
          'id': '11',
          'nombre': 'Camisa',
          'categoria': 'Camisas',
          'descripcion': null,
          'precio_base': '700.00',
          'imagen_url': null,
          'variantes': [
            {
              'id': '13',
              'sku': 'CAM-M-BLA',
              'talla': 'M',
              'color': 'Blanco',
              'precio': '725.50',
              'imagen_url': null,
              'cantidad_disponible': '20',
              'cantidad_reservada': '2',
            },
          ],
        },
      ],
    });

    expect(datos.empresaId, 7);
    expect(datos.productos.single.precioBase, 700);
    expect(datos.productos.single.variantes.single.precio, 725.5);
    expect(datos.productos.single.variantes.single.cantidadDisponible, 20);
  });
}
