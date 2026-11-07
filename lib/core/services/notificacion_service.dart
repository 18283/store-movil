import 'package:flutter/foundation.dart';

import '../models/notificacion.dart';
import '../network/api_client.dart';

class NotificacionMensaje {
  final String mensaje;
  final String tipo; // 'success', 'error', 'info'
  final DateTime timestamp;

  NotificacionMensaje({
    required this.mensaje,
    this.tipo = 'success',
  }) : timestamp = DateTime.now();
}

/// CU29 / CU35 — Servicio de notificaciones.
///
/// Combina dos responsabilidades:
/// 1. Toast en vivo: [mostrar]/[limpiar] alimentan el `NotificacionToast`
///    global (superior de la pantalla, se auto-oculta a los 5 segundos).
/// 2. Notificaciones persistidas en el backend: [cargarNotificaciones],
///    [marcarComoLeida] y [marcarTodasComoLeidas] para la campanita del
///    AppBar y la pantalla de notificaciones.
class NotificacionService extends ChangeNotifier {
  final ApiClient? _api;

  NotificacionService([this._api]);

  // ---- 1. Toast en vivo --------------------------------------------------

  NotificacionMensaje? _actual;
  NotificacionMensaje? get actual => _actual;

  void mostrar(String mensaje, [String tipo = 'success']) {
    _actual = NotificacionMensaje(mensaje: mensaje, tipo: tipo);
    notifyListeners();
  }

  void limpiar() {
    _actual = null;
    notifyListeners();
  }

  // ---- 2. Notificaciones del backend (CU35) ------------------------------

  List<Notificacion> _notificaciones = [];
  List<Notificacion> get notificaciones => List.unmodifiable(_notificaciones);

  /// Número de notificaciones sin leer (para el badge de la campanita).
  int get noLeidas => _notificaciones.where((n) => !n.leida).length;

  /// GET /notificaciones?page=1&size=50 — actualiza la lista local.
  Future<List<Notificacion>> cargarNotificaciones() async {
    final api = _api;
    if (api == null) return _notificaciones;

    final data = await api.get('/notificaciones?page=1&size=50');
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else if (data is Map && data['notificaciones'] is List) {
      list = data['notificaciones'] as List;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List;
    } else {
      list = [];
    }

    _notificaciones = list
        .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
    return _notificaciones;
  }

  /// PATCH /notificaciones/{id}/leer — la marca localmente de inmediato
  /// (actualización optimista) y luego confirma con el backend.
  Future<void> marcarComoLeida(int id) async {
    _notificaciones = _notificaciones
        .map((n) => n.id == id ? n.copyWith(leida: true) : n)
        .toList();
    notifyListeners();

    final api = _api;
    if (api == null) return;
    try {
      await api.patch('/notificaciones/$id/leer');
    } catch (_) {
      // Se conserva la actualización local: el badge ya quedó correcto.
    }
  }

  /// PATCH /notificaciones/leer-todas.
  Future<void> marcarTodasComoLeidas() async {
    _notificaciones =
        _notificaciones.map((n) => n.copyWith(leida: true)).toList();
    notifyListeners();

    final api = _api;
    if (api == null) return;
    try {
      await api.patch('/notificaciones/leer-todas');
    } catch (_) {
      // Se conserva la actualización local: el badge ya quedó correcto.
    }
  }
}
