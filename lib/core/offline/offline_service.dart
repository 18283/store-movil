import '../network/api_client.dart';
import 'offline_database.dart';
import 'offline_models.dart';

class SucursalOfflineOpcion {
  final int id;
  final String nombre;
  final String ciudad;
  const SucursalOfflineOpcion(this.id, this.nombre, this.ciudad);

  factory SucursalOfflineOpcion.fromJson(Map<String, dynamic> json) =>
      SucursalOfflineOpcion(
        json['id'] as int,
        json['nombre'] as String,
        json['ciudad'] as String,
      );
}

class OfflineService {
  final ApiClient _api;
  final OfflineDatabase _db;
  Future<DatosOffline>? _preparacionEnCurso;

  OfflineService(this._api, {OfflineDatabase? database})
    : _db = database ?? OfflineDatabase();

  Future<List<SucursalOfflineOpcion>> sucursales() async {
    final data = await _api.get('/sucursales/opciones') as List;
    return data
        .map((e) => SucursalOfflineOpcion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DatosOffline> preparar(int sucursalId) {
    if (_preparacionEnCurso != null) return _preparacionEnCurso!;
    _preparacionEnCurso = _descargar(sucursalId);
    return _preparacionEnCurso!.whenComplete(() => _preparacionEnCurso = null);
  }

  Future<DatosOffline> _descargar(int sucursalId) async {
    final data =
        await _api.get('/offline/preparar-datos?sucursal_id=$sucursalId')
            as Map<String, dynamic>;
    return _db.guardar(data);
  }

  Future<DatosOffline?> obtener(int empresaId, int sucursalId) =>
      _db.obtener(empresaId, sucursalId);

  Future<DatosOffline?> ultimoDeEmpresa(int empresaId) =>
      _db.ultimoDeEmpresa(empresaId);
}
