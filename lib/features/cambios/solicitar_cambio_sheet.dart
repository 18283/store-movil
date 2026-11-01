import 'package:flutter/material.dart';

import '../../core/models/catalogo.dart';
import '../../core/models/venta.dart';
import '../catalogo/tienda_service.dart';
import 'cambios_service.dart';

class SolicitarCambioData {
  final int ventaId;
  final ItemVenta item;

  SolicitarCambioData({required this.ventaId, required this.item});
}

/// CU18 — el cliente pide cambiar de talla/color o devolver una prenda,
/// dentro de las 48 horas desde la compra.
class SolicitarCambioSheet extends StatefulWidget {
  final SolicitarCambioData data;
  final CambiosService cambios;
  final TiendaService tienda;

  const SolicitarCambioSheet({
    super.key,
    required this.data,
    required this.cambios,
    required this.tienda,
  });

  @override
  State<SolicitarCambioSheet> createState() => _SolicitarCambioSheetState();
}

class _SolicitarCambioSheetState extends State<SolicitarCambioSheet> {
  String _tipo = 'CAMBIO';
  int _cantidad = 1;
  List<CatalogoVariante> _variantes = [];
  int? _varianteNuevaId;
  bool _cargandoVariantes = false;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final productoId = widget.data.item.productoId;
    if (productoId != null) {
      _cargarVariantes(productoId);
    }
  }

  Future<void> _cargarVariantes(int productoId) async {
    setState(() => _cargandoVariantes = true);
    try {
      final detalle = await widget.tienda.detalle(productoId);
      if (!mounted) return;
      setState(() {
        _variantes = detalle.variantes
            .where((v) => v.id != widget.data.item.varianteId)
            .toList();
        _cargandoVariantes = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoVariantes = false);
    }
  }

  bool get _puedeConfirmar => _tipo != 'CAMBIO' || _varianteNuevaId != null;

  Future<void> _confirmar() async {
    if (_procesando || !_puedeConfirmar) return;
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final solicitud = await widget.cambios.solicitar(
        ventaId: widget.data.ventaId,
        ventaDetalleId: widget.data.item.id,
        tipo: _tipo,
        varianteNuevaId: _tipo == 'CAMBIO' ? _varianteNuevaId : null,
        cantidad: _cantidad,
      );
      if (mounted) Navigator.of(context).pop(solicitud);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo crear la solicitud.');
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.data.item;
    final cantidadesPosibles = List.generate(item.cantidad, (i) => i + 1);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.producto ?? '', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Comprado: ${item.talla ?? ''} · ${item.color ?? ''} × ${item.cantidad}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CAMBIO', label: Text('Cambiar talla/color')),
                ButtonSegment(value: 'DEVOLUCION', label: Text('Devolver')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() {
                _tipo = s.first;
                _varianteNuevaId = null;
              }),
            ),
            if (_tipo == 'CAMBIO') ...[
              const SizedBox(height: 16),
              if (_cargandoVariantes)
                const Center(child: CircularProgressIndicator())
              else if (_variantes.isEmpty)
                const Text('No hay otras tallas/colores disponibles de esta prenda.')
              else
                DropdownButtonFormField<int>(
                  initialValue: _varianteNuevaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva talla / color',
                    border: OutlineInputBorder(),
                  ),
                  items: _variantes
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.talla} · ${v.color}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _varianteNuevaId = v),
                ),
            ],
            if (item.cantidad > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _cantidad,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                ),
                items: cantidadesPosibles
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) => setState(() => _cantidad = v ?? 1),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Tenés hasta 48 horas desde la compra para pedirlo. Después vas a '
              'tener que llevar la prenda a la sucursal donde compraste para '
              'completar el trámite.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _procesando || !_puedeConfirmar ? null : _confirmar,
              child: Text(_procesando ? 'Enviando…' : 'Solicitar'),
            ),
          ],
        ),
      ),
    );
  }
}
