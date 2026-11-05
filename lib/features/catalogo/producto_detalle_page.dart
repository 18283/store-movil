import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/catalogo.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/precio_promo.dart';
import '../carrito/carrito_page.dart';
import '../carrito/carrito_service.dart';
import '../reservas/agregar_reserva_sheet.dart';
import '../reservas/mi_reserva_page.dart';
import '../reservas/reservas_service.dart';
import '../vestidor/prenda_ar.dart';
import '../vestidor/vestidor_prueba_page.dart';
import '../../core/auth/auth_service.dart';
import '../traspasos/solicitar_traspaso_page.dart';
import '../traspasos/traspasos_service.dart';
import 'tienda_service.dart';

/// CU9 (detalle) + CU12 (disponibilidad) + CU16 (reservar) + CU21 (carrito).
class ProductoDetallePage extends StatefulWidget {
  final TiendaService tienda;
  final ReservasService reservas;
  final int productoId;

  const ProductoDetallePage({
    super.key,
    required this.tienda,
    required this.reservas,
    required this.productoId,
  });

  @override
  State<ProductoDetallePage> createState() => _ProductoDetallePageState();
}

class _ProductoDetallePageState extends State<ProductoDetallePage> {
  bool _cargando = true;
  bool _noEncontrado = false;
  bool _agregandoCarrito = false;
  CatalogoProductoDetalle? _producto;

  int? _colorSel;
  int? _tallaSel;

  List<DisponibilidadSucursal> _disponibilidad = [];
  bool _cargandoDisponibilidad = false;

  List<CatalogoVariante> get _variantes => _producto?.variantes ?? [];

  List<CatalogoVariante> get _coloresUnicos {
    final vistos = <int, CatalogoVariante>{};
    for (final v in _variantes) {
      vistos.putIfAbsent(v.colorId, () => v);
    }
    return vistos.values.toList();
  }

  List<CatalogoVariante> get _tallasParaColorSel {
    if (_colorSel == null) return _variantes;
    return _variantes.where((v) => v.colorId == _colorSel).toList();
  }

  CatalogoVariante? get _varianteSeleccionada {
    try {
      return _variantes.firstWhere(
        (v) => v.colorId == _colorSel && v.tallaId == _tallaSel,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final producto = await widget.tienda.detalle(widget.productoId);
      if (!mounted) return;
      setState(() {
        _producto = producto;
        _cargando = false;
        if (producto.variantes.isNotEmpty) {
          _colorSel = producto.variantes.first.colorId;
          _tallaSel = producto.variantes.first.tallaId;
        }
      });
      _cargarDisponibilidad();
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _noEncontrado = true;
        });
      }
    }
  }

  Future<void> _cargarDisponibilidad() async {
    final variante = _varianteSeleccionada;
    if (variante == null) {
      setState(() => _disponibilidad = []);
      return;
    }
    setState(() => _cargandoDisponibilidad = true);
    try {
      final res = await widget.tienda.disponibilidad(variante.id);
      if (!mounted) return;
      setState(() {
        _disponibilidad = res;
        _cargandoDisponibilidad = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _disponibilidad = [];
          _cargandoDisponibilidad = false;
        });
      }
    }
  }

  void _elegirColor(int colorId) {
    setState(() {
      _colorSel = colorId;
      final disponibles = _tallasParaColorSel;
      if (!disponibles.any((v) => v.tallaId == _tallaSel)) {
        _tallaSel = disponibles.isNotEmpty ? disponibles.first.tallaId : null;
      }
    });
    _cargarDisponibilidad();
  }

  void _elegirTalla(int tallaId) {
    setState(() => _tallaSel = tallaId);
    _cargarDisponibilidad();
  }

  /// CU20 — abre el vestidor virtual con las variantes del producto que tienen
  /// imagen AR (una por color), empezando por la variante elegida.
  void _probarEnVestidor() {
    final producto = _producto;
    final actual = _varianteSeleccionada;
    if (producto == null || actual == null || !actual.tieneAr) return;

    final porColor = <int, CatalogoVariante>{};
    for (final v in producto.variantes) {
      if (v.tieneAr) porColor.putIfAbsent(v.colorId, () => v);
    }
    porColor[actual.colorId] = actual;

    final prendas = porColor.values
        .map((v) => PrendaAr.desdeVariante(v, nombreProducto: producto.nombre))
        .toList();
    final inicial = prendas.firstWhere(
      (p) => p.url == actual.imagenArUrl,
      orElse: () => prendas.first,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VestidorPruebaPage(prendas: prendas, inicial: inicial),
      ),
    );
  }

  Future<void> _agregarAReserva() async {
    final variante = _varianteSeleccionada;
    if (variante == null || _disponibilidad.isEmpty || _producto == null) {
      return;
    }
    final agregada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AgregarReservaSheet(
        data: AgregarReservaData(
          varianteId: variante.id,
          productoNombre: _producto!.nombre,
          talla: variante.talla,
          color: variante.color,
          imagenUrl: variante.imagenEfectivo ?? _producto!.imagenUrl,
          sucursales: _disponibilidad,
        ),
      ),
    );
    if (agregada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Agregada a tu reserva.'),
          action: SnackBarAction(
            label: 'Ver mi reserva',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MiReservaPage(reservas: widget.reservas),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _agregarAlCarrito() async {
    final variante = _varianteSeleccionada;
    if (variante == null) return;

    setState(() => _agregandoCarrito = true);
    try {
      await context.read<CarritoService>().agregar(
        varianteId: variante.id,
        cantidad: 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Se agregó al carrito.'),
          action: SnackBarAction(
            label: 'Ver carrito',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CarritoPage()),
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo agregar al carrito.')),
        );
      }
    } finally {
      if (mounted) setState(() => _agregandoCarrito = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_noEncontrado || _producto == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Producto no encontrado.')),
      );
    }

    final auth = context.watch<AuthService>();
    final rol = auth.usuario?.rol;
    final puedeSolicitarTraspaso = rol == 'Cliente' ||
        rol == 'EncargadoSucursal' ||
        rol == 'Encargado';

    final producto = _producto!;
    final variante = _varianteSeleccionada;
    final imagen = variante?.imagenEfectivo ?? producto.imagenUrl;
    final precio = variante?.precioEfectivo ?? producto.precioBase;
    final precioPromo = variante != null
        ? variante.precioPromocional
        : producto.precioPromocional;
    final etiquetaPromo = variante != null ? variante.promocion : producto.promocion;

    return Scaffold(
      appBar: AppBar(title: Text(producto.nombre)),
      // SafeArea evita que la barra de navegación del celular tape los
      // botones de abajo (gestos o los 3 botones, según el dispositivo).
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: imagen == null
                      ? const Icon(Icons.checkroom, size: 64)
                      : Image.network(
                          imagen,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.checkroom, size: 64),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              producto.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (producto.categoria != null) ...[
              const SizedBox(height: 4),
              Text(
                producto.categoria!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 8),
            PrecioPromo(
              precio: precio,
              precioPromocional: precioPromo,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (precioPromo != null && etiquetaPromo != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: EtiquetaOferta(etiquetaPromo),
              ),
            ],
            if (producto.descripcion != null &&
                producto.descripcion!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(producto.descripcion!),
            ],
            const SizedBox(height: 20),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _coloresUnicos.map((v) {
                final sel = _colorSel == v.colorId;
                return GestureDetector(
                  onTap: () => _elegirColor(v.colorId),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _colorDesdeHex(v.colorHex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: sel ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Talla', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _tallasParaColorSel.map((v) {
                final sel = _tallaSel == v.tallaId;
                return ChoiceChip(
                  label: Text(v.talla ?? '-'),
                  selected: sel,
                  onSelected: (_) => _elegirTalla(v.tallaId),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Disponible en',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (_cargandoDisponibilidad)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_disponibilidad.isEmpty)
              const Text('Sin stock en ninguna sucursal por ahora.')
            else
              ..._disponibilidad.map(
                (d) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(d.sucursal),
                  subtitle: Text(d.ciudad),
                  trailing: Text('${d.cantidadDisponible} und.'),
                ),
              ),
            const SizedBox(height: 24),
            // CU20: solo aparece si la variante elegida tiene imagen de RA.
            if (variante != null && variante.tieneAr) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _probarEnVestidor,
                      icon: const Icon(Icons.checkroom_outlined),
                      label: const Text('Probar en vestidor virtual'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (variante != null && _disponibilidad.isNotEmpty)
                        ? _agregarAReserva
                        : null,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Agregar a mi reserva'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (variante == null || _agregandoCarrito)
                        ? null
                        : _agregarAlCarrito,
                    icon: _agregandoCarrito
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Agregar al carrito'),
                  ),
                ),
              ],
            ),
            if (puedeSolicitarTraspaso) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SolicitarTraspasoPage(
                              service: TraspasosService(auth.api),
                              varianteIdInicial: variante?.id,
                              queryInicial: producto.nombre,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Solicitar traspaso a otra sucursal'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _colorDesdeHex(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  final limpio = hex.replaceAll('#', '');
  final valor = int.tryParse('FF$limpio', radix: 16);
  return valor == null ? Colors.grey : Color(valor);
}
