import 'dart:math';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'offline_database.dart';
import 'offline_models.dart';

String _generarClave() {
  final rnd = Random();
  final sufijo = List.generate(
    8,
    (_) => rnd.nextInt(36).toRadixString(36),
  ).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$sufijo';
}

class ResultadoSincronizacion {
  final int confirmadas;
  final int rechazadas;
  const ResultadoSincronizacion(this.confirmadas, this.rechazadas);
}

/// CU11/CU12 — guardan la reserva/venta en la cola local (SQLite) sin tocar
/// el servidor. CU13 lee esa cola. CU14 la sincroniza apenas vuelve la
/// conexión, con la clave de idempotencia de cada una (un reintento nunca
/// la duplica). CU15 es el resultado que queda en cada operación.
class OfflineSyncService {
  final ApiClient _api;
  final OfflineDatabase _db;
  bool _sincronizando = false;

  OfflineSyncService(this._api, {OfflineDatabase? database})
    : _db = database ?? OfflineDatabase();

  Future<List<OperacionPendiente>> listar() => _db.listarOperaciones();

  Future<void> registrarReserva(Map<String, dynamic> payload, String resumen) =>
      _encolar('RESERVA', payload, resumen);

  Future<void> registrarVenta(Map<String, dynamic> payload, String resumen) =>
      _encolar('VENTA', payload, resumen);

  Future<void> _encolar(
    String tipo,
    Map<String, dynamic> payload,
    String resumen,
  ) async {
    final op = OperacionPendiente(
      claveIdempotencia: _generarClave(),
      tipo: tipo,
      estado: EstadoOperacionLocal.local,
      creadoEnDispositivo: DateTime.now(),
      resumen: resumen,
      payload: payload,
    );
    await _db.guardarOperacion(op);
  }

  Future<ResultadoSincronizacion> sincronizar() async {
    if (_sincronizando) return const ResultadoSincronizacion(0, 0);
    _sincronizando = true;
    var confirmadas = 0;
    var rechazadas = 0;
    try {
      final pendientes = (await _db.listarOperaciones())
          .where((op) => op.estado == EstadoOperacionLocal.local)
          .toList();
      for (final op in pendientes) {
        await _db.guardarOperacion(
          op.copyWith(estado: EstadoOperacionLocal.enviando),
        );
        final ruta = op.tipo == 'RESERVA' ? 'reservas' : 'ventas';
        final cuerpo = {
          'clave_idempotencia': op.claveIdempotencia,
          'creado_en_dispositivo': op.creadoEnDispositivo.toIso8601String(),
          ...op.payload,
        };
        try {
          final data =
              await _api.post('/offline/sincronizar/$ruta', body: cuerpo)
                  as Map<String, dynamic>;
          final estado = estadoOperacionDesdeTexto(data['estado'] as String);
          await _db.guardarOperacion(
            op.copyWith(
              estado: estado,
              motivoRechazo: data['motivo_rechazo'] as String?,
              reservaId: data['reserva_id'] as int?,
              ventaId: data['venta_id'] as int?,
            ),
          );
          if (estado == EstadoOperacionLocal.confirmado) {
            confirmadas++;
          } else {
            rechazadas++;
          }
        } on ApiException {
          // Se cortó la conexión a mitad de camino: vuelve a LOCAL y se
          // reintenta en la próxima sincronización. No se pierde.
          await _db.guardarOperacion(
            op.copyWith(estado: EstadoOperacionLocal.local),
          );
        }
      }
    } finally {
      _sincronizando = false;
    }
    return ResultadoSincronizacion(confirmadas, rechazadas);
  }
}
