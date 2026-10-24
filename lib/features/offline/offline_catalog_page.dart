import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/offline/offline_models.dart';
import '../../core/offline/offline_service.dart';

class OfflineCatalogPage extends StatefulWidget {
  final OfflineService service;
  final int empresaId;
  final int? sucursalInicialId;

  const OfflineCatalogPage({
    super.key,
    required this.service,
    required this.empresaId,
    this.sucursalInicialId,
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

  @override
  void initState() {
    super.initState();
    _sucursalId = widget.sucursalInicialId;
    _inicializar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
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
        ],
      ),
    );
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
            trailing: Text(
              item.variante.precio == null
                  ? '—'
                  : 'Bs ${item.variante.precio!.toStringAsFixed(2)}',
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
