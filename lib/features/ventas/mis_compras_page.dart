import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/venta.dart';
import '../../core/widgets/precio_promo.dart';
import '../cambios/cambios_service.dart';
import '../cambios/solicitar_cambio_sheet.dart';
import '../catalogo/tienda_service.dart';
import 'ventas_service.dart';

const int _plazoHorasCambio = 48;

/// CU22/CU28 — Mis compras: historial + confirma pagos pendientes al abrir
/// (cubre el caso de haber pagado escaneando el QR desde otro dispositivo,
/// donde nunca se abrió una pantalla de "resultado" que hiciera el polling).
/// También CU18 — pedir un cambio o devolución de una prenda ya comprada.
class MisComprasPage extends StatefulWidget {
  final VentasService ventas;
  final CambiosService cambios;
  final TiendaService tienda;

  const MisComprasPage({
    super.key,
    required this.ventas,
    required this.cambios,
    required this.tienda,
  });

  @override
  State<MisComprasPage> createState() => _MisComprasPageState();
}

class _MisComprasPageState extends State<MisComprasPage> {
  bool _cargando = true;
  List<Venta> _ventas = [];
  int? _procesando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await widget.ventas.misCompras();
      if (!mounted) return;
      setState(() {
        _ventas = res;
        _cargando = false;
      });
      _revisarPendientes(res);
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _revisarPendientes(List<Venta> ventas) async {
    for (final venta in ventas) {
      if (venta.estado != 'PENDIENTE_PAGO') continue;
      try {
        final info = await widget.ventas.estadoPago(venta.id);
        if (!mounted) return;
        if (info.ventaEstado == venta.estado) continue;
        setState(() {
          _ventas = _ventas
              .map((v) => v.id == venta.id ? v.copyWithEstado(info.ventaEstado) : v)
              .toList();
        });
      } catch (_) {
        // silencioso: no bloquea el resto de la lista.
      }
    }
  }

  Future<void> _reintentarPago(Venta venta) async {
    setState(() => _procesando = venta.id);
    try {
      final pago = await widget.ventas.iniciarPago(venta.id);
      if (pago.checkoutUrl != null) {
        await launchUrl(
          Uri.parse(pago.checkoutUrl!),
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar un nuevo link de pago.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  Future<void> _cancelar(Venta venta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Cancelar este pedido? El stock se libera.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _procesando = venta.id);
    try {
      final actualizada = await widget.ventas.cancelar(venta.id);
      if (!mounted) return;
      setState(() {
        _ventas = _ventas
            .map((v) => v.id == actualizada.id ? actualizada : v)
            .toList();
        _procesando = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido cancelado.')));
    } catch (_) {
      if (mounted) {
        setState(() => _procesando = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar el pedido.')),
        );
      }
    }
  }

  bool _puedeSolicitarCambio(Venta venta) {
    if (venta.estado != 'PAGADA' && venta.estado != 'COMPLETADA') return false;
    final creada = DateTime.tryParse(venta.fechaCreacion);
    if (creada == null) return false;
    final limite = creada.add(const Duration(hours: _plazoHorasCambio));
    return DateTime.now().isBefore(limite);
  }

  Future<void> _solicitarCambio(Venta venta, ItemVenta item) async {
    final solicitud = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SolicitarCambioSheet(
        data: SolicitarCambioData(ventaId: venta.id, item: item),
        cambios: widget.cambios,
        tienda: widget.tienda,
      ),
    );
    if (solicitud != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. Llevá la prenda a la sucursal.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis compras')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _ventas.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.receipt_long_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('Todavía no hiciste ninguna compra.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _ventas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _TarjetaVenta(
                  venta: _ventas[i],
                  procesando: _procesando == _ventas[i].id,
                  onReintentar: () => _reintentarPago(_ventas[i]),
                  onCancelar: () => _cancelar(_ventas[i]),
                  puedeSolicitarCambio: _puedeSolicitarCambio(_ventas[i]),
                  onSolicitarCambio: (item) => _solicitarCambio(_ventas[i], item),
                ),
              ),
      ),
    );
  }
}

class _TarjetaVenta extends StatelessWidget {
  final Venta venta;
  final bool procesando;
  final VoidCallback onReintentar;
  final VoidCallback onCancelar;
  final bool puedeSolicitarCambio;
  final void Function(ItemVenta item) onSolicitarCambio;

  const _TarjetaVenta({
    required this.venta,
    required this.procesando,
    required this.onReintentar,
    required this.onCancelar,
    required this.puedeSolicitarCambio,
    required this.onSolicitarCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${venta.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    etiquetaEstadoVenta[venta.estado] ?? venta.estado,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${venta.direccionEntrega != null ? 'Despacho desde' : 'Compra en'} ${venta.sucursal}'
              '${venta.ciudad != null ? ' — ${venta.ciudad}' : ''}',
            ),
            if (venta.direccionEntrega != null) ...[
              const SizedBox(height: 2),
              Text(
                'Entrega en ${venta.direccionEntrega}'
                '${venta.referenciaEntrega != null ? ' (${venta.referenciaEntrega})' : ''}',
              ),
            ],
            const SizedBox(height: 8),
            ...venta.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.producto ?? ''} · ${item.talla ?? ''}/${item.color ?? ''} × ${item.cantidad}'
                            '${venta.variasSucursales ? ' — desde ${item.sucursal}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PrecioPromo(
                          precio: item.precioOriginal != null &&
                                  item.precioOriginal! > item.precioUnitario
                              ? item.precioOriginal!
                              : item.precioUnitario,
                          precioPromocional: item.precioOriginal != null &&
                                  item.precioOriginal! > item.precioUnitario
                              ? item.precioUnitario
                              : null,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (puedeSolicitarCambio)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => onSolicitarCambio(item),
                          icon: const Icon(Icons.sync_alt, size: 16),
                          label: const Text('Cambio o devolución'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (venta.ahorro > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Ahorraste Bs ${venta.ahorro.toStringAsFixed(2)} con promociones',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorOferta,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Total: Bs ${venta.total.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (venta.estado == 'PENDIENTE_PAGO' && venta.reservaId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Se cobra en caja',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (venta.estado == 'PENDIENTE_PAGO') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: procesando ? null : onCancelar,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: procesando ? null : onReintentar,
                    child: Text(procesando ? 'Abriendo…' : 'Pagar ahora'),
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
