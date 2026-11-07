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

  /// PUT? No — GET /notificaciones?page=1&size=50 (CU35: centro de notificaciones).
  ///
  /// Soporta paginación y filtro opcional por estado de lectura:
  /// - [page]: página solicitada (1 = primera página, reemplaza la lista).
  /// - [size]: cantidad por página.
  /// - [leidas]: si se pasa, filtra por estado (true = solo leídas, false = solo no leídas).
  /// - [append]: true agrega la página a la lista actual (para scroll infinito).
  /// La lista queda ordenada por fecha descendente (más reciente primero).
  Future<List<Notificacion>> cargarNotificaciones({
    int page = 1,
    int size = 50,
    bool? leidas,
    bool append = false,
  }) async {
    final api = _api;
    if (api == null) return _notificaciones;

    final params = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      if (leidas != null) 'leidas': leidas.toString(),
    };
    final query = Uri(queryParameters: params).query;
    final data = await api.get('/notificaciones?$query');
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

    final nuevas = list
        .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();

    if (append) {
      // Evita duplicados al paginar (el backend páginas superpuestas por
      // inserciones nuevas entre requests).
      // Evita duplicados al paginar (el backend páginas superpuestas por
      // inserciones nuevas entre requests).
      final idsExistentes = _notificaciones.map((n) => n.id).toSet();
      _notificaciones = [
        ..._notificaciones,
        ...nuevas.where((n) => !idsExistentes.contains(n.id)),
      ];
    } else {
      _notificaciones = nuevas;
    }
    _notificaciones.sort((a, b) => b.fecha.compareTo(a.fecha));
    notifyListeners();
    return _notificaciones;
  }

  /// POST /notificaciones/masiva — solo Administrador.
  /// Envía una notificación a los usuarios con los roles indicados y
  /// devuelve la cantidad de destinatarios alcanzados ({enviados: N}).
  Future<int> enviarMasiva({
    required String mensaje,
    required String tipo,
    required List<String> rolesDestino,
  }) async {
    final api = _api;
    if (api == null) return 0;

    final data = await api.post('/notificaciones/masiva', body: {
      'mensaje': mensaje.trim(),
      'tipo': tipo,
      'roles_destino': rolesDestino.map((r) => r.trim()).where((r) => r.isNotEmpty).toList(),
    });

    if (data is Map) {
      final enviados = data['enviados'] ?? data['cantidad'] ?? data['total'];
      if (enviados is int) return enviados;
      if (enviados is num) return enviados.toInt();
      if (enviados is String) return int.tryParse(enviados) ?? 0;
    }
    return 0;
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
