import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../account/account_page.dart';
import '../carrito/carrito_page.dart';
import '../carrito/carrito_service.dart';
import '../catalogo/catalogo_page.dart';
import '../catalogo/tienda_service.dart';
import '../ia/asistente_page.dart';
import '../ia/ia_service.dart';
import '../../core/offline/offline_service.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/offline/push_service.dart';
import '../../core/offline/tarjeta_service.dart';
import '../cambios/cambios_service.dart';
import '../cambios/mis_cambios_page.dart';
import '../traspasos/solicitar_traspaso_page.dart';
import '../traspasos/traspasos_service.dart';
import '../traspasos/seguimiento_traspaso_page.dart';
import '../offline/offline_catalog_page.dart';
import '../reservas/mi_reserva_page.dart';
import '../reservas/mis_reservas_page.dart';
import '../reservas/reserva_bolsa_service.dart';
import '../reservas/reservas_service.dart';
import '../vestidor/vestidor_prueba_page.dart';
import '../ventas/mis_compras_page.dart';
import '../ventas/ventas_service.dart';

enum _MenuCuenta {
  cuenta,
  miReserva,
  reservas,
  compras,
  cambios,
  traspasosMenu,
  asistente,
  vestidorPrueba,
  catalogoOffline,
  salir,
}

/// Home autenticado: catálogo (CU9/CU10) como contenido principal,
/// carrito y menú de cuenta (reservas/compras/datos/logout) en el AppBar.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Carga el carrito una vez al entrar, para que el badge del ícono
    // ya muestre la cantidad real sin esperar a abrir "Mi carrito".
    context.read<CarritoService>().cargar().catchError((_) {});
  }

  void _onMenu(_MenuCuenta opcion) {
    final auth = context.read<AuthService>();
    switch (opcion) {
      case _MenuCuenta.cuenta:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AccountPage()));
        break;
      case _MenuCuenta.miReserva:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MiReservaPage(reservas: ReservasService(auth.api)),
          ),
        );
        break;
      case _MenuCuenta.reservas:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MisReservasPage(reservas: ReservasService(auth.api)),
          ),
        );
        break;
      case _MenuCuenta.compras:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MisComprasPage(
              ventas: VentasService(auth.api),
              cambios: CambiosService(auth.api),
              tienda: TiendaService(auth.api),
            ),
          ),
        );
        break;
      case _MenuCuenta.cambios:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MisCambiosPage(cambios: CambiosService(auth.api)),
          ),
        );
        break;
      case _MenuCuenta.traspasosMenu:
        _mostrarMenuTraspasos(auth);
        break;
      case _MenuCuenta.asistente:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AsistentePage(ia: IaService(auth.api)),
          ),
        );
        break;
      case _MenuCuenta.vestidorPrueba:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const VestidorPruebaPage()));
        break;
      case _MenuCuenta.catalogoOffline:
        final empresaId = auth.usuario?.empresaId;
        if (empresaId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El usuario no está asociado a una empresa.'),
            ),
          );
          break;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OfflineCatalogPage(
              service: OfflineService(auth.api),
              syncService: OfflineSyncService(auth.api),
              tarjetaService: TarjetaService(auth.api),
              pushService: context.read<PushService>(),
              empresaId: empresaId,
              sucursalInicialId: auth.usuario?.sucursalId,
              esCliente: auth.usuario?.rol == 'Cliente',
            ),
          ),
        );
        break;
      case _MenuCuenta.salir:
        context.read<CarritoService>().limpiarLocal();
        context.read<ReservaBolsaService>().limpiar();
        auth.logout();
        break;
    }
  }

  void _mostrarMenuTraspasos(AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: Colors.green),
            SizedBox(width: 8),
            Text('Traspasos'),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Solicitar traspaso'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SolicitarTraspasoPage(service: TraspasosService(auth.api)),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.query_stats),
              title: const Text('Seguimiento de traspaso'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SeguimientoTraspasoPage(service: TraspasosService(auth.api)),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final rol = auth.usuario?.rol;
    final puedeSolicitarTraspaso = rol == 'Cliente' ||
        rol == 'EncargadoSucursal' ||
        rol == 'Encargado';
    final cantidadCarrito = context.watch<CarritoService>().cantidadItems;
    final cantidadReserva = context.watch<ReservaBolsaService>().cantidad;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FashionStore'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$cantidadCarrito'),
              isLabelVisible: cantidadCarrito > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            tooltip: 'Mi carrito',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CarritoPage())),
          ),
          PopupMenuButton<_MenuCuenta>(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi cuenta',
            onSelected: _onMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _MenuCuenta.cuenta,
                child: ListTile(
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Mi cuenta'),
                ),
              ),
              PopupMenuItem(
                value: _MenuCuenta.miReserva,
                child: ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    cantidadReserva > 0
                        ? 'Mi reserva ($cantidadReserva)'
                        : 'Mi reserva',
                  ),
                ),
              ),
              const PopupMenuItem(
                value: _MenuCuenta.reservas,
                child: ListTile(
                  leading: Icon(Icons.event_note_outlined),
                  title: Text('Mis reservas'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuCuenta.compras,
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Mis compras'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuCuenta.cambios,
                child: ListTile(
                  leading: Icon(Icons.sync_alt),
                  title: Text('Mis cambios y devoluciones'),
                ),
              ),
              if (puedeSolicitarTraspaso || rol == 'Cliente' || rol == 'EncargadoSucursal')
                const PopupMenuItem(
                  value: _MenuCuenta.traspasosMenu,
                  child: ListTile(
                    leading: Icon(Icons.local_shipping_outlined),
                    title: Text('Traspasos'),
                  ),
                ),
              const PopupMenuItem(
                value: _MenuCuenta.asistente,
                child: ListTile(
                  leading: Icon(Icons.smart_toy_outlined),
                  title: Text('Asistente virtual'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuCuenta.catalogoOffline,
                child: ListTile(
                  leading: Icon(Icons.offline_pin_outlined),
                  title: Text('Catálogo sin conexión'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuCuenta.vestidorPrueba,
                child: ListTile(
                  leading: Icon(Icons.checkroom_outlined),
                  title: Text('Vestidor virtual (prueba)'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuCuenta.salir,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CatalogoPage(
        tienda: TiendaService(auth.api),
        reservas: ReservasService(auth.api),
        ia: IaService(auth.api),
      ),
    );
  }
}
