import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../app_keys.dart';
import '../network/api_client.dart';

/// CU14/CU15 — notificación push real: avisa el resultado de sincronizar una
/// reserva/venta registrada sin conexión, aunque la app esté en segundo plano
/// o cerrada. Si falla (sin Google Play Services, permiso negado, etc.) el
/// resto de la app sigue funcionando igual, solo sin el aviso push.
class PushService {
  final ApiClient _api;
  bool _escuchando = false;

  PushService(this._api);

  Future<bool> habilitar() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      final concedido =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!concedido) return false;

      final token = await messaging.getToken();
      if (token == null) return false;

      await _api.post(
        '/offline/dispositivos',
        body: {'token': token, 'plataforma': 'ANDROID'},
      );

      if (!_escuchando) {
        _escuchando = true;
        FirebaseMessaging.onMessage.listen((message) {
          final titulo = message.notification?.title ?? 'FashionStore';
          final cuerpo = message.notification?.body ?? '';
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('$titulo — $cuerpo'),
              duration: const Duration(seconds: 5),
            ),
          );
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
