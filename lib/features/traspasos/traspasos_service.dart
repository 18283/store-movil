import '../../core/models/traspaso.dart';
import '../../core/network/api_client.dart';

/// CU24 — Solicitar traspaso de prenda (código anterior: CU61).
/// Servicio que comunica la aplicación móvil con el módulo `/traspasos` del backend.
class TraspasosService {
  final ApiClient _api;

  TraspasosService(this._api);

  /// Mensajes 2-9 del diagrama: Opciones de traspaso (rol, sucursales y destino permitido).
  Future<OpcionesTraspaso> opciones() async {
    final data = await _api.get('/traspasos/opciones');
    return OpcionesTraspaso.fromJson(data as Map<String, dynamic>);
  }

  /// Mensajes 12-19 del diagrama: Variantes activas con sucursales y stock disponible.
  Future<List<VarianteConStock>> buscarVariantes({
    String? q,
    int? varianteId,
    int limite = 30,
  }) async {
    final params = <String, String>{};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (varianteId != null) params['variante_id'] = varianteId.toString();
    params['limite'] = limite.toString();

    final query = Uri(queryParameters: params).query;
    final path = query.isEmpty ? '/traspasos/variantes' : '/traspasos/variantes?$query';

    final data = await _api.get(path);
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else {
      list = [];
    }

    return list.map((e) => VarianteConStock.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Mensajes 22-39 del diagrama: Registrar solicitud de traspaso en estado PENDIENTE.
  Future<SolicitudTraspaso> solicitar({
    required int varianteId,
    required int origenId,
    required int destinoId,
    required int cantidad,
    String? motivo,
    bool confirmarStockDestino = false,
  }) async {
    final body = <String, dynamic>{
      'variante_id': varianteId,
      'origen_id': origenId,
      'destino_id': destinoId,
      'cantidad': cantidad,
      'motivo': motivo != null && motivo.trim().isNotEmpty ? motivo.trim() : null,
      'confirmar_stock_destino': confirmarStockDestino,
    };

    final data = await _api.post('/traspasos', body: body);
    return SolicitudTraspaso.fromJson(data as Map<String, dynamic>);
  }

  /// CU28 — Consultar seguimiento de traspaso (código anterior: CU65).
  /// Actores: Cliente, Encargado de sucursal.
  Future<SolicitudTraspaso> consultarSeguimiento(String codigo) async {
    final data = await _api.get('/traspasos/${Uri.encodeComponent(codigo.trim())}');
    return SolicitudTraspaso.fromJson(data as Map<String, dynamic>);
  }

  /// Mensajes CU28: Listar todas las solicitudes de traspaso de la empresa.
  /// Retorna un listado paginado o completo de solicitudes según la configuración del backend.
  Future<List<SolicitudTraspaso>> listarTraspasos() async {
    final data = await _api.get('/traspasos');
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else {
      list = [];
    }
    return list.map((e) => SolicitudTraspaso.fromJson(e as Map<String, dynamic>)).toList();
  }
}
