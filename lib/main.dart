import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_keys.dart';
import 'core/auth/auth_service.dart';
import 'core/offline/push_service.dart';
import 'core/services/notificacion_service.dart';
import 'features/auth/login_page.dart';
import 'features/carrito/carrito_service.dart';
import 'features/home/home_page.dart';
import 'features/reservas/reserva_bolsa_service.dart';
import 'shared/notificacion_toast.dart';

// CU14/CU15 — FCM necesita este handler top-level (fuera de cualquier clase)
// para procesar push mientras la app está en segundo plano o cerrada. Como
// ya se manda el payload "notification", Android la muestra solo: acá no
// hace falta hacer nada más.
@pragma('vm:entry-point')
Future<void> _manejarPushEnSegundoPlano(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_manejarPushEnSegundoPlano);
  } catch (_) {
    // Sin Google Play Services o sin configurar: la app sigue andando,
    // simplemente no habrá notificaciones push.
  }
  runApp(const FashionStoreApp());
}

class FashionStoreApp extends StatelessWidget {
  const FashionStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..cargarSesion()),
        ChangeNotifierProxyProvider<AuthService, NotificacionService>(
          create: (context) => NotificacionService(context.read<AuthService>().api),
          update: (context, auth, previo) => previo ?? NotificacionService(auth.api),
        ),
        // Se crea una sola vez con el ApiClient de AuthService (mismo token)
        // y sobrevive mientras dure la app, como el carrito real.
        ChangeNotifierProvider(create: (_) => ReservaBolsaService()),
        ChangeNotifierProxyProvider<AuthService, CarritoService>(
          create: (context) => CarritoService(context.read<AuthService>().api),
          update: (context, auth, previo) => previo ?? CarritoService(auth.api),
        ),
        Provider<PushService>(
          create: (context) => PushService(context.read<AuthService>().api),
        ),
      ],
      child: MaterialApp(
        title: 'FashionStore',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        builder: (context, child) {
          return NotificacionToast(
            service: context.read<NotificacionService>(),
            child: child ?? const SizedBox.shrink(),
          );
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide qué pantalla mostrar según el estado de sesión.
/// Mientras se restaura el token guardado, o al iniciar/cerrar sesión,
/// AuthService notifica y este widget cambia solo (sin manejar rutas a mano).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return auth.estaAutenticado ? const HomePage() : const LoginPage();
  }
}
