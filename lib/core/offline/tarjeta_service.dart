import '../network/api_client.dart';

class TarjetaEstado {
  final bool tieneTarjetaGuardada;
  const TarjetaEstado(this.tieneTarjetaGuardada);

  factory TarjetaEstado.fromJson(Map<String, dynamic> json) =>
      TarjetaEstado(json['tiene_tarjeta_guardada'] as bool);
}

/// CU12/CU14 — tarjeta guardada en Stripe, necesaria para poder cobrar una
/// compra registrada sin conexión recién al sincronizar (CU14). Mismo patrón
/// que el pago normal (CU27): se abre una pestaña de Stripe y, al volver a
/// la app, se confirma sin depender de ningún link ni parámetro de retorno.
class TarjetaService {
  final ApiClient _api;
  TarjetaService(this._api);

  Future<TarjetaEstado> estado() async {
    final data = await _api.get('/ventas/tarjeta') as Map<String, dynamic>;
    return TarjetaEstado.fromJson(data);
  }

  Future<String> iniciarGuardado() async {
    final data =
        await _api.post('/ventas/tarjeta/iniciar') as Map<String, dynamic>;
    return data['checkout_url'] as String;
  }

  Future<TarjetaEstado> confirmar() async {
    final data =
        await _api.post('/ventas/tarjeta/confirmar') as Map<String, dynamic>;
    return TarjetaEstado.fromJson(data);
  }

  Future<TarjetaEstado> eliminar() async {
    final data = await _api.delete('/ventas/tarjeta') as Map<String, dynamic>;
    return TarjetaEstado.fromJson(data);
  }
}
