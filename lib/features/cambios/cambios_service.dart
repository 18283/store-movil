import '../../core/models/cambio.dart';
import '../../core/network/api_client.dart';

/// CU18/CU23 (lado cliente) — solicitar un cambio o devolución y consultar
/// el historial propio. Recepción/resolución (CU19-21) son del cajero,
/// que solo usa la web.
class CambiosService {
  final ApiClient _api;

  CambiosService(this._api);

  Future<Solicitud> solicitar({
    required int ventaId,
    required int ventaDetalleId,
    required String tipo,
    int? varianteNuevaId,
    required int cantidad,
  }) async {
    final data = await _api.post(
      '/cambios',
      body: {
        'venta_id': ventaId,
        'venta_detalle_id': ventaDetalleId,
        'tipo': tipo,
        'variante_nueva_id': varianteNuevaId,
        'cantidad': cantidad,
      },
    );
    return Solicitud.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Solicitud>> mias() async {
    final data = await _api.get('/cambios/mias') as List;
    return data.map((e) => Solicitud.fromJson(e)).toList();
  }
}
