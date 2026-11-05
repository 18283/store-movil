import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:store_movil/core/models/traspaso.dart';
import 'package:store_movil/core/network/api_client.dart';
import 'package:store_movil/features/traspasos/solicitar_traspaso_page.dart';
import 'package:store_movil/features/traspasos/traspasos_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(getToken: () => 'fake_token');

  dynamic getResponse;
  dynamic postResponse;
  String? lastGetPath;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<dynamic> get(String path, {bool auth = true}) async {
    lastGetPath = path;
    if (getResponse is Exception) {
      throw getResponse;
    }
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    if (postResponse is Exception) {
      throw postResponse;
    }
    return postResponse;
  }
}

void main() {
  group('CU24 Modelos de Traspaso', () {
    test('OpcionesTraspaso deserializa correctamente', () {
      final json = {
        'rol': 'Cliente',
        'empresa_id': 1,
        'cliente_id': 10,
        'sucursal_asignada_id': null,
        'sucursales': [
          {'id': 1, 'nombre': 'Centro', 'ciudad': 'Santa Cruz'},
          {'id': 2, 'nombre': 'Norte', 'ciudad': 'La Paz'},
        ],
        'destino_permitido_id': null,
      };

      final op = OpcionesTraspaso.fromJson(json);
      expect(op.rol, 'Cliente');
      expect(op.clienteId, 10);
      expect(op.sucursalAsignadaId, isNull);
      expect(op.sucursales.length, 2);
      expect(op.sucursales.first.nombre, 'Centro');
      expect(op.destinoPermitidoId, isNull);
    });

    test('VarianteConStock deserializa fila plana', () {
      final json = {
        'variante_id': 101,
        'producto_id': 5,
        'producto': 'Camisa Lino',
        'sku': 'CAM-LIN-M',
        'talla': 'M',
        'color': 'Azul',
        'color_hex': '#0000FF',
        'origen_id': 1,
        'origen': 'Centro',
        'ciudad': 'Santa Cruz',
        'cantidad_disponible': 8,
      };

      final v = VarianteConStock.fromJson(json);
      expect(v.varianteId, 101);
      expect(v.producto, 'Camisa Lino');
      expect(v.sku, 'CAM-LIN-M');
      expect(v.origenId, 1);
      expect(v.cantidadDisponible, 8);
    });

    test('SolicitudTraspaso deserializa respuesta PENDIENTE', () {
      final json = {
        'id': 1,
        'codigo': 'TRP-20261101-0001',
        'estado': 'PENDIENTE',
        'resumen': '1 × Camisa Lino desde Centro hacia Norte. Estado: PENDIENTE.',
        'variante_id': 101,
        'variante': 'Camisa Lino · M · Azul',
        'producto_id': 5,
        'producto': 'Camisa Lino',
        'sku': 'CAM-LIN-M',
        'talla': 'M',
        'color': 'Azul',
        'origen_id': 1,
        'origen': 'Centro',
        'ciudad_origen': 'Santa Cruz',
        'destino_id': 2,
        'destino': 'Norte',
        'ciudad_destino': 'La Paz',
        'cantidad': 1,
        'motivo': 'Prueba para cliente',
        'solicitante': 'Carla Cliente',
        'solicitante_rol': 'Cliente',
        'fecha_solicitud': '2026-11-01T12:00:00Z',
        'stock_origen': 8,
        'stock_destino': 0,
      };

      final s = SolicitudTraspaso.fromJson(json);
      expect(s.codigo, 'TRP-20261101-0001');
      expect(s.estado, 'PENDIENTE');
      expect(s.cantidad, 1);
      expect(s.origen, 'Centro');
      expect(s.destino, 'Norte');
    });
  });

  group('CU24 TraspasosService', () {
    late FakeApiClient fakeApi;
    late TraspasosService service;

    setUp(() {
      fakeApi = FakeApiClient();
      service = TraspasosService(fakeApi);
    });

    test('opciones() llama a /traspasos/opciones', () async {
      fakeApi.getResponse = {
        'rol': 'EncargadoSucursal',
        'empresa_id': 1,
        'sucursal_asignada_id': 2,
        'sucursales': [
          {'id': 1, 'nombre': 'Centro', 'ciudad': 'Santa Cruz'},
          {'id': 2, 'nombre': 'Norte', 'ciudad': 'La Paz'},
        ],
        'destino_permitido_id': 2,
      };

      final res = await service.opciones();
      expect(fakeApi.lastGetPath, '/traspasos/opciones');
      expect(res.rol, 'EncargadoSucursal');
      expect(res.destinoPermitidoId, 2);
    });

    test('buscarVariantes() arma query params y devuelve lista', () async {
      fakeApi.getResponse = {
        'items': [
          {
            'variante_id': 101,
            'producto': 'Camisa Lino',
            'origen_id': 1,
            'origen': 'Centro',
            'ciudad': 'Santa Cruz',
            'cantidad_disponible': 4,
          }
        ],
        'total': 1,
      };

      final items = await service.buscarVariantes(q: 'lino', limite: 10);
      expect(fakeApi.lastGetPath, contains('/traspasos/variantes?'));
      expect(fakeApi.lastGetPath, contains('q=lino'));
      expect(items.length, 1);
      expect(items.first.producto, 'Camisa Lino');
    });

    test('solicitar() envía body con confirmar_stock_destino', () async {
      fakeApi.postResponse = {
        'id': 12,
        'codigo': 'TRP-20261101-0002',
        'estado': 'PENDIENTE',
        'variante_id': 101,
        'origen_id': 1,
        'destino_id': 2,
        'cantidad': 2,
        'motivo': 'Pedido cliente',
      };

      final res = await service.solicitar(
        varianteId: 101,
        origenId: 1,
        destinoId: 2,
        cantidad: 2,
        motivo: 'Pedido cliente',
        confirmarStockDestino: true,
      );

      expect(fakeApi.lastPostPath, '/traspasos');
      expect(fakeApi.lastPostBody?['variante_id'], 101);
      expect(fakeApi.lastPostBody?['origen_id'], 1);
      expect(fakeApi.lastPostBody?['destino_id'], 2);
      expect(fakeApi.lastPostBody?['cantidad'], 2);
      expect(fakeApi.lastPostBody?['motivo'], 'Pedido cliente');
      expect(fakeApi.lastPostBody?['confirmar_stock_destino'], isTrue);
      expect(res.codigo, 'TRP-20261101-0002');
      expect(res.estado, 'PENDIENTE');
    });


  });

  group('CU24 SolicitarTraspasoPage Widget', () {
    late FakeApiClient fakeApi;
    late TraspasosService service;

    setUp(() {
      fakeApi = FakeApiClient();
      service = TraspasosService(fakeApi);
    });

    testWidgets('Carga opciones y muestra formulario', (tester) async {
      fakeApi.getResponse = {
        'rol': 'Cliente',
        'sucursales': [
          {'id': 1, 'nombre': 'Centro', 'ciudad': 'Santa Cruz'},
          {'id': 2, 'nombre': 'Norte', 'ciudad': 'La Paz'},
        ],
        'destino_permitido_id': null,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: SolicitarTraspasoPage(service: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Solicitar traspaso de prenda'), findsOneWidget);
      expect(find.text('1. Buscá la prenda'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

