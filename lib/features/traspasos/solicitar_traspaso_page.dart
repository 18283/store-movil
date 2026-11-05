import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/models/traspaso.dart';
import '../../core/network/api_exception.dart';
import 'traspasos_service.dart';

class VarianteAgrupada {
  final int varianteId;
  final String producto;
  final String? sku;
  final String? talla;
  final String? color;
  final List<VarianteConStock> origenes;

  VarianteAgrupada({
    required this.varianteId,
    required this.producto,
    this.sku,
    this.talla,
    this.color,
    required this.origenes,
  });
}

/// CU24 — Solicitar traspaso de prenda (móvil).
///
/// Actores:
/// - Cliente: elige libremente la sucursal de destino entre las activas.
/// - EncargadoSucursal: destino fijo hacia su propia sucursal asignada.
///
/// Modulo: Traspasos (código anterior: CU61).
/// Alcance: Solicitar que una variante sea enviada a otra sucursal.
class SolicitarTraspasoPage extends StatefulWidget {
  final TraspasosService service;
  final int? varianteIdInicial;
  final String? queryInicial;

  const SolicitarTraspasoPage({
    super.key,
    required this.service,
    this.varianteIdInicial,
    this.queryInicial,
  });

  @override
  State<SolicitarTraspasoPage> createState() => _SolicitarTraspasoPageState();
}

class _SolicitarTraspasoPageState extends State<SolicitarTraspasoPage> {
  final _qCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  Timer? _debounce;

  bool _cargandoOpciones = true;
  String? _errorOpciones;
  OpcionesTraspaso? _opciones;

  bool _buscando = false;
  bool _busco = false;
  List<VarianteConStock> _resultados = [];
  String? _errorBusqueda;

  int? _varianteId;
  int? _origenId;
  int? _destinoId;
  int _cantidad = 1;

  bool _enviando = false;
  String? _error;
  SolicitudTraspaso? _resultado;

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
    _qCtrl.addListener(_onBusquedaCambiada);

    if (widget.queryInicial != null && widget.queryInicial!.trim().isNotEmpty) {
      _qCtrl.text = widget.queryInicial!.trim();
      _buscar(
        widget.queryInicial!.trim(),
        varianteIdAutoSeleccionar: widget.varianteIdInicial,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.dispose();
    _motivoCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  /// Mensajes 1-10: Carga inicial de opciones, sucursales y rol permitido.
  Future<void> _cargarOpciones() async {
    setState(() {
      _cargandoOpciones = true;
      _errorOpciones = null;
    });
    try {
      final op = await widget.service.opciones();
      if (!mounted) return;
      setState(() {
        _opciones = op;
        _cargandoOpciones = false;
        if (op.destinoPermitidoId != null) {
          _destinoId = op.destinoPermitidoId;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoOpciones = false;
        _errorOpciones = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoOpciones = false;
        _errorOpciones = 'No se pudieron cargar las opciones de traspaso.';
      });
    }
  }

  void _onBusquedaCambiada() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final texto = _qCtrl.text.trim();
      if (texto.length < 2) {
        setState(() {
          _resultados = [];
          _busco = false;
          _buscando = false;
          _errorBusqueda = null;
        });
        _sincronizarSeleccion();
        return;
      }
      _buscar(texto);
    });
  }

  /// Mensajes 11-20: Buscar variantes activas con stock en sucursales de origen.
  Future<void> _buscar(String texto, {int? varianteIdAutoSeleccionar}) async {
    setState(() {
      _buscando = true;
      _busco = true;
      _errorBusqueda = null;
    });
    try {
      final res = await widget.service.buscarVariantes(q: texto);
      if (!mounted) return;
      setState(() {
        _resultados = res;
        _buscando = false;
      });
      _sincronizarSeleccion();

      if (varianteIdAutoSeleccionar != null && _varianteId == null) {
        for (final v in _variantesAgrupadas) {
          if (v.varianteId == varianteIdAutoSeleccionar) {
            _elegirVariante(v);
            break;
          }
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _buscando = false;
        _errorBusqueda = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _buscando = false;
        _errorBusqueda = 'No se pudo completar la búsqueda.';
      });
    }
  }

  List<VarianteAgrupada> get _variantesAgrupadas {
    final mapa = <int, VarianteAgrupada>{};
    for (final fila in _resultados) {
      var v = mapa[fila.varianteId];
      if (v == null) {
        v = VarianteAgrupada(
          varianteId: fila.varianteId,
          producto: fila.producto,
          sku: fila.sku,
          talla: fila.talla,
          color: fila.color,
          origenes: [],
        );
        mapa[fila.varianteId] = v;
      }
      v.origenes.add(fila);
    }
    final lista = mapa.values.toList();
    lista.sort((a, b) => a.producto.compareTo(b.producto));
    return lista;
  }

  VarianteAgrupada? get _varianteSeleccionada {
    if (_varianteId == null) return null;
    for (final v in _variantesAgrupadas) {
      if (v.varianteId == _varianteId) return v;
    }
    return null;
  }

  VarianteConStock? get _origenSeleccionado {
    final v = _varianteSeleccionada;
    if (v == null || _origenId == null) return null;
    for (final o in v.origenes) {
      if (o.origenId == _origenId) return o;
    }
    return null;
  }

  int get _maxCantidad => _origenSeleccionado?.cantidadDisponible ?? 0;

  int? get _destinoPermitidoId => _opciones?.destinoPermitidoId;

  List<SucursalTraspaso> get _destinosDisponibles {
    final op = _opciones;
    if (op == null) return [];
    final fijo = op.destinoPermitidoId;
    return op.sucursales
        .where((s) => s.id != _origenId && (fijo == null || s.id == fijo))
        .toList();
  }

  int? get _stockDestino {
    final v = _varianteSeleccionada;
    final dest = _destinoId;
    if (v == null || dest == null) return null;
    for (final o in v.origenes) {
      if (o.origenId == dest) return o.cantidadDisponible;
    }
    return 0;
  }

  void _sincronizarSeleccion() {
    final id = _varianteId;
    if (id == null) return;
    final v = _varianteSeleccionada;
    if (v == null) {
      setState(() {
        _varianteId = null;
        _origenId = null;
        _cantidad = 1;
        _cantidadCtrl.text = '1';
        _destinoId = _destinoPermitidoId;
      });
      return;
    }

    if (!_origenSeleccionadoExiste(v)) {
      var mejor = v.origenes.first;
      for (final o in v.origenes) {
        if (o.cantidadDisponible > mejor.cantidadDisponible) mejor = o;
      }
      setState(() {
        _origenId = mejor.origenId;
        _cantidad = 1;
        _cantidadCtrl.text = '1';
        final fijo = _destinoPermitidoId;
        _destinoId = fijo != null && fijo != mejor.origenId ? fijo : null;
      });
      return;
    }

    if (_cantidad > _maxCantidad) {
      final nuevo = _maxCantidad > 0 ? _maxCantidad : 1;
      setState(() {
        _cantidad = nuevo;
        _cantidadCtrl.text = '$nuevo';
      });
    }
  }

  bool _origenSeleccionadoExiste(VarianteAgrupada v) {
    if (_origenId == null) return false;
    return v.origenes.any((o) => o.origenId == _origenId);
  }

  bool get _puedeEnviar {
    final varId = _varianteId;
    final origId = _origenId;
    final destId = _destinoId;
    return varId != null &&
        origId != null &&
        destId != null &&
        origId != destId &&
        _cantidad >= 1 &&
        _cantidad <= _maxCantidad &&
        !_enviando;
  }

  void _elegirVariante(VarianteAgrupada v) {
    if (_varianteId == v.varianteId) return;
    var mejor = v.origenes.first;
    for (final o in v.origenes) {
      if (o.cantidadDisponible > mejor.cantidadDisponible) mejor = o;
    }
    setState(() {
      _varianteId = v.varianteId;
      _origenId = mejor.origenId;
      _cantidad = 1;
      _cantidadCtrl.text = '1';
      final fijo = _destinoPermitidoId;
      _destinoId = fijo != null && fijo != mejor.origenId ? fijo : null;
      _error = null;
    });
  }

  Future<void> _solicitar() async {
    if (!_puedeEnviar) return;
    await _enviar(false);
  }

  /// Mensajes 21-40: Envío, validación transaccional, confirmación de stock
  /// y control de solicitudes pendientes duplicadas.
  Future<void> _enviar(bool confirmarStock) async {
    final varId = _varianteId;
    final origId = _origenId;
    final destId = _destinoId;
    if (varId == null || origId == null || destId == null) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final res = await widget.service.solicitar(
        varianteId: varId,
        origenId: origId,
        destinoId: destId,
        cantidad: _cantidad,
        motivo: _motivoCtrl.text,
        confirmarStockDestino: confirmarStock,
      );

      // Paso 32/33: Si el backend pide confirmación por stock existente en destino
      if (res.requiereConfirmacion && !confirmarStock) {
        final confirmar = await _mostrarDialogoConfirmacionStock(res.mensaje);
        if (confirmar == true) {
          await _enviar(true);
          return;
        } else {
          if (!mounted) return;
          setState(() => _enviando = false);
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _resultado = res;
        _enviando = false;
      });
    } on ApiException catch (e) {
      // Paso 32/33: Confirmar si en destino ya hay stock suficiente
      if (!confirmarStock &&
          (e.codigo == 'STOCK_DESTINO_SUFICIENTE' ||
              e.codigo == 'CONFIRMACION_STOCK_DESTINO' ||
              e.detalle?['requiere_confirmacion'] == true)) {
        final confirmar = await _mostrarDialogoConfirmacionStock(e.message);
        if (confirmar == true) {
          await _enviar(true);
          return;
        }
      }

      // Paso 34/35: Solicitud pendiente duplicada -> informar al usuario
      if (e.codigo == 'SOLICITUD_PENDIENTE_EXISTENTE') {
        if (!mounted) return;
        setState(() => _enviando = false);
        await _mostrarDialogoDuplicada(e.message);
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = e.message;
        _enviando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo registrar la solicitud.';
        _enviando = false;
      });
    }
  }

  /// Mensajes 32-33: Diálogo modal cuando el destino ya tiene stock suficiente.
  Future<bool?> _mostrarDialogoConfirmacionStock(String? mensaje) async {
    final destinoNombre = _opciones?.sucursales
            .firstWhere(
              (s) => s.id == _destinoId,
              orElse: () => SucursalTraspaso(
                id: 0,
                nombre: 'la sucursal destino',
                ciudad: '',
              ),
            )
            .nombre ??
        'la sucursal destino';
    final stock = _stockDestino ?? 1;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La sucursal destino ya tiene stock'),
        content: Text(
          mensaje ??
              'En $destinoNombre ya hay $stock '
                  '${stock == 1 ? 'unidad disponible' : 'unidades disponibles'} '
                  'de esta prenda. El traspaso se puede pedir igual, pero puede '
                  'que no haga falta mover la prenda. ¿Querés continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, solicitar'),
          ),
        ],
      ),
    );
  }

  /// Si ya existe una solicitud PENDIENTE idéntica,
  /// no se crea otra e informa al usuario.
  Future<void> _mostrarDialogoDuplicada(String mensaje) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Solicitud existente'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje),
            const SizedBox(height: 12),
            Text(
              'No se creará otra solicitud.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _nuevaSolicitud() {
    setState(() {
      _resultado = null;
      _qCtrl.clear();
      _motivoCtrl.clear();
      _cantidadCtrl.text = '1';
      _resultados = [];
      _busco = false;
      _errorBusqueda = null;
      _varianteId = null;
      _origenId = null;
      _cantidad = 1;
      _destinoId = _destinoPermitidoId;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final esEncargado = _opciones?.rol == 'EncargadoSucursal' ||
        _opciones?.rol == 'Encargado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar traspaso de prenda'),
      ),
      body: _cargandoOpciones
          ? const Center(child: CircularProgressIndicator())
          : _errorOpciones != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(_errorOpciones!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _cargarOpciones,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _resultado != null
                  ? _buildResultado(theme, textTheme)
                  : _buildFormulario(
                      theme,
                      textTheme,
                      colorScheme,
                      esEncargado,
                    ),
    );
  }

  /// Mensajes 39-40: Mostrar resumen de la solicitud en PENDIENTE.
  Widget _buildResultado(ThemeData theme, TextTheme textTheme) {
    final r = _resultado!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solicitud ${r.codigo} registrada',
                    style: textTheme.titleLarge,
                  ),
                  Text(
                    'Estado: ${r.estado}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filaResumen(
                  'Prenda',
                  r.variante ??
                      _varianteSeleccionada?.producto ??
                      '—',
                ),
                const Divider(height: 16),
                _filaResumen(
                  'Origen',
                  r.origen ??
                      _origenSeleccionado?.origen ??
                      '—',
                ),
                const Divider(height: 16),
                _filaResumen(
                  'Destino',
                  r.destino ??
                      _opciones?.sucursales
                          .firstWhere(
                            (s) => s.id == _destinoId,
                            orElse: () => SucursalTraspaso(
                              id: 0,
                              nombre: '—',
                              ciudad: '',
                            ),
                          )
                          .nombre ??
                      '—',
                ),
                const Divider(height: 16),
                _filaResumen('Cantidad', '${r.cantidad}'),
                if (r.motivo != null && r.motivo!.isNotEmpty) ...[
                  const Divider(height: 16),
                  _filaResumen('Motivo', r.motivo!),
                ],
              ],
            ),
          ),
        ),
        if (r.resumen != null && r.resumen!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            r.resumen!,
            style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'El stock todavía no cambia: se mueve cuando la sucursal de '
                'origen despache la prenda. La solicitud queda disponible para '
                'evaluación y seguimiento.',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _nuevaSolicitud,
          icon: const Icon(Icons.add),
          label: const Text('Hacer otra solicitud'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver a la tienda'),
        ),
      ],
    );
  }

  Widget _filaResumen(String label, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  /// Formulario de solicitud (Pasos 10-22)
  Widget _buildFormulario(
    ThemeData theme,
    TextTheme textTheme,
    ColorScheme colorScheme,
    bool esEncargado,
  ) {
    final v = _varianteSeleccionada;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          esEncargado
              ? 'Pedí que una prenda con stock en otra sucursal llegue a la tuya (CU24).'
              : 'Elegí una prenda y la sucursal donde querés probártela: la enviamos desde otra sucursal (CU24).',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 20),
        Text('1. Buscá la prenda', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _qCtrl,
          decoration: InputDecoration(
            labelText: 'Producto, SKU, talla o color',
            hintText: 'Ej. camisa, CAM-001, M, negro',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _buscando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Escribí al menos 2 caracteres. Solo se muestran prendas con stock en otras sucursales.',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        if (_errorBusqueda != null) ...[
          const SizedBox(height: 8),
          Text(_errorBusqueda!, style: TextStyle(color: colorScheme.error)),
        ],
        if (_busco &&
            !_buscando &&
            _variantesAgrupadas.isEmpty &&
            _errorBusqueda == null) ...[
          const SizedBox(height: 12),
          const Text(
            'No encontramos esa prenda con stock en otras sucursales, '
            'así que no se puede generar una solicitud de traspaso.',
          ),
        ],
        if (_variantesAgrupadas.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._variantesAgrupadas.map((item) {
            final seleccionado = _varianteId == item.varianteId;
            return Card(
              color: seleccionado
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : null,
              child: ListTile(
                title: Text(
                  item.producto,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text([
                  if (item.talla != null) item.talla,
                  if (item.color != null) item.color,
                  if (item.sku != null) item.sku,
                ].join(' · ')),
                trailing: Wrap(
                  spacing: 4,
                  children: item.origenes
                      .map((o) => Chip(
                            label: Text(
                              '${o.origen}: ${o.cantidadDisponible}',
                            ),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                onTap: () => _elegirVariante(item),
              ),
            );
          }),
        ],
        if (v != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('2. Origen, destino y cantidad', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.checkroom),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.producto,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${v.talla ?? '—'} · ${v.color ?? '—'}${v.sku != null ? ' · ${v.sku}' : ''}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _enviando
                      ? null
                      : () => setState(() => _varianteId = null),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('origen_${_origenId}_${v.origenes.length}'),
            initialValue: _origenId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sucursal de origen',
              border: OutlineInputBorder(),
              helperText: 'Solo sucursales con stock de esta variante.',
            ),
            items: v.origenes
                .map((o) => DropdownMenuItem(
                      value: o.origenId,
                      child: Text(
                        '${o.origen} — ${o.ciudad} (${o.cantidadDisponible})',
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _origenId = val;
                _cantidad = 1;
                _cantidadCtrl.text = '1';
                if (_destinoId == val) _destinoId = null;
                final fijo = _destinoPermitidoId;
                if (fijo != null && fijo != val) _destinoId = fijo;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('destino_${_destinoId}_${_destinosDisponibles.length}'),
            initialValue: _destinoId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sucursal de destino',
              border: const OutlineInputBorder(),
              helperText: esEncargado
                  ? 'Tu rol solo permite enviar a tu sucursal.'
                  : null,
            ),
            items: _destinosDisponibles
                .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.nombre} — ${s.ciudad}'),
                    ))
                .toList(),
            onChanged: esEncargado || _opciones?.destinoPermitidoId != null
                ? null
                : (val) => setState(() {
                      _destinoId = val;
                      _error = null;
                    }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    border: const OutlineInputBorder(),
                    helperText: 'Máximo $_maxCantidad en origen.',
                  ),
                  onChanged: (val) {
                    final n = int.tryParse(val);
                    if (n != null) {
                      setState(() => _cantidad = n);
                    }
                  },
                  onFieldSubmitted: (val) {
                    final n = int.tryParse(val) ?? 1;
                    final max = _maxCantidad;
                    final normal = n.clamp(1, max > 0 ? max : 1);
                    setState(() {
                      _cantidad = normal;
                      _cantidadCtrl.text = '$normal';
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motivoCtrl,
            maxLines: 2,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Motivo u observación (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_stockDestino != null && _stockDestino! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En la sucursal destino ya hay ${_stockDestino!} '
                    '${_stockDestino! == 1 ? 'unidad' : 'unidades'} '
                    'de esta prenda. Si continuás, te vamos a pedir confirmación.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: !_puedeEnviar ? null : _solicitar,
            icon: const Icon(Icons.local_shipping),
            label: Text(_enviando ? 'Enviando…' : 'Solicitar traspaso'),
          ),
        ],
      ],
    );
  }
}
