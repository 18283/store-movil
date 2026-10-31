import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/offline/offline_models.dart';
import '../../core/offline/offline_service.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/offline/push_service.dart';
import '../../core/offline/tarjeta_service.dart';

class ItemPedidoOffline {
  final int varianteId;
  int cantidad;
  final String producto;
  final String talla;
  final String color;
  ItemPedidoOffline({
    required this.varianteId,
    required this.cantidad,
    required this.producto,
    required this.talla,
    required this.color,
  });
}

class OfflineCatalogPage extends StatefulWidget {
  final OfflineService service;
  final OfflineSyncService syncService;
  final TarjetaService tarjetaService;
  final PushService pushService;
  final int empresaId;
  final int? sucursalInicialId;
  final bool esCliente;

  const OfflineCatalogPage({
    super.key,
    required this.service,
    required this.syncService,
    required this.tarjetaService,
    required this.pushService,
    required this.empresaId,
    this.sucursalInicialId,
    required this.esCliente,
  });

  @override
  State<OfflineCatalogPage> createState() => _OfflineCatalogPageState();
}

class _OfflineCatalogPageState extends State<OfflineCatalogPage> {
  final _busquedaCtrl = TextEditingController();
  Timer? _debounce;
  List<SucursalOfflineOpcion> _sucursales = [];
  DatosOffline? _datos;
  int? _sucursalId;
  String _talla = '';
  String _color = '';
  bool _cargando = true;
  bool _sincronizando = false;
  bool _online = true;
  String? _error;
  String? _exito;

  // CU11/CU12 — pedido en construcción sin conexión.
  final List<ItemPedidoOffline> _pedido = [];
  bool _tieneTarjeta = false;

  // CU13/CU14/CU15 — cola de operaciones pendientes.
  List<OperacionPendiente> _operaciones = [];
  bool _sincronizandoPendientes = false;

  @override
  void initState() {
    super.initState();
    _sucursalId = widget.sucursalInicialId;
    _inicializar();
    if (widget.esCliente) {
      _cargarOperaciones();
      widget.tarjetaService
          .estado()
          .then((e) => mounted ? setState(() => _tieneTarjeta = e.tieneTarjetaGuardada) : null)
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarOperaciones() async {
    final ops = await widget.syncService.listar();
    if (mounted) setState(() => _operaciones = ops);
  }

  void _agregarAlPedido(VarianteOfflineVista item) {
    final existente = _pedido
        .where((i) => i.varianteId == item.variante.id)
        .toList();
    if (existente.isNotEmpty) {
      setState(() => existente.first.cantidad++);
      return;
    }
    setState(() => _pedido.add(
          ItemPedidoOffline(
            varianteId: item.variante.id,
            cantidad: 1,
            producto: item.producto.nombre,
            talla: item.variante.talla,
            color: item.variante.color,
          ),
        ));
  }

  void _quitarDelPedido(int varianteId) {
    setState(() => _pedido.removeWhere((i) => i.varianteId == varianteId));
  }

  List<Map<String, dynamic>> get _itemsPedidoJson => _pedido
      .map((i) => {'variante_id': i.varianteId, 'cantidad': i.cantidad})
      .toList();

  Future<void> _abrirFormularioReserva() async {
    if (_pedido.isEmpty || _sucursalId == null) return;
    final datos = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormularioReservaOffline(),
    );
    if (datos == null) return;
    await widget.syncService.registrarReserva(
      {
        'sucursal_id': _sucursalId,
        'fecha': datos['fecha'],
        'hora_inicio': datos['hora_inicio'],
        'duracion_minutos': datos['duracion_minutos'],
        'items': _itemsPedidoJson,
      },
      'Reserva de ${_pedido.length} prenda(s) para el ${datos['fecha']} ${datos['hora_inicio']}',
    );
    setState(() {
      _pedido.clear();
      _exito = 'Reserva guardada en este dispositivo. Se confirmará apenas vuelva la conexión.';
    });
    await _cargarOperaciones();
  }

  Future<void> _abrirFormularioVenta() async {
    if (_pedido.isEmpty) return;
    if (!_tieneTarjeta) {
      setState(() => _error = 'Necesitás guardar una tarjeta en "Mi cuenta" antes de comprar sin conexión.');
      return;
    }
    final datos = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormularioVentaOffline(),
    );
    if (datos == null) return;
    await widget.syncService.registrarVenta(
      {
        'items': _itemsPedidoJson,
        'direccion_entrega': datos['direccion_entrega'],
        'referencia_entrega': datos['referencia_entrega'],
      },
      'Compra de ${_pedido.length} prenda(s)',
    );
    setState(() {
      _pedido.clear();
      _exito = 'Compra guardada en este dispositivo. Se cobrará a tu tarjeta guardada apenas vuelva la conexión.';
    });
    await _cargarOperaciones();
  }

  Future<void> _sincronizarPendientes() async {
    if (_sincronizandoPendientes) return;
    setState(() => _sincronizandoPendientes = true);
    try {
      final r = await widget.syncService.sincronizar();
      if (r.confirmadas > 0 || r.rechazadas > 0) {
        setState(() {
          _exito = 'Sincronización: ${r.confirmadas} confirmada(s), ${r.rechazadas} rechazada(s).';
        });
      }
      await _cargarOperaciones();
    } finally {
      if (mounted) setState(() => _sincronizandoPendientes = false);
    }
  }

  Future<void> _habilitarPush() async {
    final ok = await widget.pushService.habilitar();
    if (mounted) {
      setState(() => _exito = ok ? 'Notificaciones activadas.' : 'No se pudieron activar las notificaciones.');
    }
  }

  Future<void> _inicializar() async {
    try {
      _datos = _sucursalId == null
          ? await widget.service.ultimoDeEmpresa(widget.empresaId)
          : await widget.service.obtener(widget.empresaId, _sucursalId!);
      _sucursalId ??= _datos?.sucursalId;
    } catch (e) {
      _error = _mensaje(e, 'No se pudieron leer los datos locales.');
    }
    if (mounted) setState(() => _cargando = false);
    try {
      final opciones = await widget.service.sucursales();
      if (!mounted) return;
      setState(() {
        _online = true;
        _sucursales = opciones;
        if (_sucursalId == null && opciones.length == 1) {
          _sucursalId = opciones.first.id;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  Future<void> _cambiarSucursal(int? id) async {
    if (id == null || _sincronizando) return;
    setState(() {
      _sucursalId = id;
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.service.obtener(widget.empresaId, id);
      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _mensaje(e, 'No se pudo leer la copia local.'));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _sincronizar() async {
    final sucursalId = _sucursalId;
    if (sucursalId == null || _sincronizando) return;
    setState(() {
      _sincronizando = true;
      _error = null;
      _exito = null;
    });
    try {
      final datos = await widget.service.preparar(sucursalId);
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _online = true;
        _exito =
            'Datos preparados: ${datos.productos.length} productos y ${datos.totalVariantes} variantes.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _online = false;
        _error = _mensaje(
          e,
          'No se pudo actualizar. Se conserva la última copia válida.',
        );
      });
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  List<VarianteOfflineVista> get _resultados => filtrarDatosOffline(
    _datos,
    busqueda: _busquedaCtrl.text,
    talla: _talla,
    color: _color,
  );

  List<String> get _tallas => {
    for (final p in _datos?.productos ?? <ProductoOffline>[])
      for (final v in p.variantes) v.talla,
  }.toList()..sort();

  List<String> get _colores => {
    for (final p in _datos?.productos ?? <ProductoOffline>[])
      for (final v in p.variantes) v.color,
  }.toList()..sort();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo sin conexión'),
        actions: [
          if (widget.esCliente)
            IconButton(
              tooltip: 'Activar notificaciones',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _habilitarPush,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _online ? Icons.wifi : Icons.wifi_off,
              color: _online ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_cargando || _sincronizando) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final selector = DropdownButtonFormField<int>(
                      initialValue: _sucursalId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sucursal',
                        border: OutlineInputBorder(),
                      ),
                      items: _sucursales
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.nombre} — ${s.ciudad}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _sincronizando ? null : _cambiarSucursal,
                    );
                    final boton = FilledButton.icon(
                      onPressed: _sincronizando || _sucursalId == null
                          ? null
                          : _sincronizar,
                      icon: const Icon(Icons.sync),
                      label: Text(_datos == null ? 'Preparar' : 'Actualizar'),
                    );

                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [selector, const SizedBox(height: 8), boton],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: selector),
                        const SizedBox(width: 8),
                        boton,
                      ],
                    );
                  },
                ),
                if (_error != null)
                  _mensajeWidget(
                    _error!,
                    Colors.red.shade50,
                    Colors.red.shade800,
                  ),
                if (_exito != null)
                  _mensajeWidget(
                    _exito!,
                    Colors.green.shade50,
                    Colors.green.shade800,
                  ),
                if (_datos != null) ...[
                  _mensajeWidget(
                    'Las existencias pueden estar desactualizadas. Última sincronización: ${_fecha(_datos!.guardadoEn)}.',
                    Colors.amber.shade50,
                    Colors.brown.shade700,
                  ),
                  TextField(
                    controller: _busquedaCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar nombre, categoría o SKU',
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 350), () {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _talla,
                          decoration: const InputDecoration(labelText: 'Talla'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Todas'),
                            ),
                            ..._tallas.map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _talla = v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _color,
                          decoration: const InputDecoration(labelText: 'Color'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Todos'),
                            ),
                            ..._colores.map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _color = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _contenido()),
          if (widget.esCliente) ..._panelPedidoYCola(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------- #
  //  CU11/CU12/CU13/CU14/CU15 — Pedido sin conexión y cola de sincronización
  // --------------------------------------------------------------------------- #
  List<Widget> _panelPedidoYCola() {
    final widgets = <Widget>[];

    if (_pedido.isNotEmpty) {
      widgets.add(
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: const Border(top: BorderSide(color: Colors.black12)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pedido sin conexión', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in _pedido)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${i.producto} · ${i.talla} · ${i.color} × ${i.cantidad}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _quitarDelPedido(i.varianteId),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: const Text('Reservar'),
                      onPressed: _abrirFormularioReserva,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Comprar'),
                      onPressed: _abrirFormularioVenta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_operaciones.isNotEmpty) {
      widgets.add(
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reservas y compras sin conexión', style: Theme.of(context).textTheme.titleSmall),
                  FilledButton.icon(
                    icon: _sincronizandoPendientes
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: const Text('Sincronizar'),
                    onPressed: _sincronizandoPendientes ? null : _sincronizarPendientes,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final op in _operaciones)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          op.tipo == 'RESERVA' ? Icons.event : Icons.shopping_bag,
                        ),
                        title: Text(op.resumen, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          op.etiquetaEstado,
                          style: TextStyle(
                            color: op.estado == EstadoOperacionLocal.confirmado
                                ? Colors.green
                                : op.estado == EstadoOperacionLocal.rechazado
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _contenido() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_datos == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No existen datos locales. Con conexión, seleccioná una sucursal y presioná Preparar.',
          ),
        ),
      );
    }
    final items = _resultados;
    if (items.isEmpty) {
      return const Center(
        child: Text('No existen productos para los filtros seleccionados.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return Card(
          child: ListTile(
            leading: item.variante.imagenUrl == null
                ? const Icon(Icons.checkroom)
                : Image.network(
                    item.variante.imagenUrl!,
                    width: 56,
                    errorBuilder: (_, _, _) => const Icon(Icons.checkroom),
                  ),
            title: Text(item.producto.nombre),
            subtitle: Text(
              '${item.producto.categoria} · ${item.variante.talla} · ${item.variante.color}\nÚltima disponibilidad: ${item.variante.cantidadDisponible}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.variante.precio == null
                      ? '—'
                      : 'Bs ${item.variante.precio!.toStringAsFixed(2)}',
                ),
                if (widget.esCliente)
                  IconButton(
                    tooltip: 'Agregar al pedido offline',
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: () => _agregarAlPedido(item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mensajeWidget(String texto, Color fondo, Color color) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(texto, style: TextStyle(color: color)),
  );

  String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} '
      '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  String _mensaje(Object error, String defecto) {
    final texto = error.toString().replaceFirst('ApiException: ', '');
    return texto.isEmpty ? defecto : texto;
  }
}

/// CU11 — fecha, hora y duración del turno para una reserva sin conexión.
/// No valida turnos libres en vivo (necesitaría conexión): el servidor
/// decide al sincronizar (CU14) si el turno sigue disponible.
class _FormularioReservaOffline extends StatefulWidget {
  @override
  State<_FormularioReservaOffline> createState() => _FormularioReservaOfflineState();
}

class _FormularioReservaOfflineState extends State<_FormularioReservaOffline> {
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  int _duracion = 30;

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(context: context, initialTime: _hora);
    if (elegida != null) setState(() => _hora = elegida);
  }

  void _confirmar() {
    final fechaTexto =
        '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';
    final horaTexto =
        '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}:00';
    Navigator.of(context).pop({
      'fecha': fechaTexto,
      'hora_inicio': horaTexto,
      'duracion_minutos': _duracion,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reservar sin conexión', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text(_fecha.toString().split(' ').first),
            trailing: const Icon(Icons.calendar_today),
            onTap: _elegirFecha,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora'),
            subtitle: Text(_hora.format(context)),
            trailing: const Icon(Icons.access_time),
            onTap: _elegirHora,
          ),
          DropdownButtonFormField<int>(
            initialValue: _duracion,
            decoration: const InputDecoration(labelText: 'Duración'),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 minutos')),
              DropdownMenuItem(value: 60, child: Text('60 minutos')),
            ],
            onChanged: (v) => setState(() => _duracion = v ?? 30),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirmar,
            child: const Text('Guardar reserva local'),
          ),
        ],
      ),
    );
  }
}

/// CU12 — dirección de entrega para una venta de contado sin conexión.
class _FormularioVentaOffline extends StatefulWidget {
  @override
  State<_FormularioVentaOffline> createState() => _FormularioVentaOfflineState();
}

class _FormularioVentaOfflineState extends State<_FormularioVentaOffline> {
  final _direccionCtrl = TextEditingController();
  final _referenciaCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _referenciaCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final direccion = _direccionCtrl.text.trim();
    if (direccion.length < 5) {
      setState(() => _error = 'Ingresá una dirección de entrega válida.');
      return;
    }
    final referencia = _referenciaCtrl.text.trim();
    Navigator.of(context).pop({
      'direccion_entrega': direccion,
      'referencia_entrega': referencia.isEmpty ? null : referencia,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comprar sin conexión', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Se cobrará a tu tarjeta guardada apenas vuelva la conexión.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _direccionCtrl,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Dirección de entrega',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _referenciaCtrl,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Referencia (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirmar,
            child: const Text('Guardar compra local'),
          ),
        ],
      ),
    );
  }
}
