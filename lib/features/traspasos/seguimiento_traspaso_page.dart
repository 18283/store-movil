import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/traspaso.dart';
import '../../core/network/api_exception.dart';
import 'traspasos_service.dart';

/// CU28 — Consultar seguimiento de traspaso (código anterior: CU65).
///
/// Actores: Cliente, Encargado de sucursal.
/// Plataforma: Web y móvil.
/// Módulo: Traspasos.
/// Alcance: Consultar estado solicitado, aprobado, enviado, recibido o cancelado.
///
/// Comportamiento tipo-web en Angular: el buscador está siempre visible arriba
/// y la lista se carga automáticamente al entrar.
class SeguimientoTraspasoPage extends StatefulWidget {
  final TraspasosService service;
  final String? codigoInicial;

  const SeguimientoTraspasoPage({
    super.key,
    required this.service,
    this.codigoInicial,
  });

  @override
  State<SeguimientoTraspasoPage> createState() => _SeguimientoTraspasoPageState();
}

class _SeguimientoTraspasoPageState extends State<SeguimientoTraspasoPage> {
  final _codigoCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;
  List<SolicitudTraspaso> _listaTraspasos = [];
  List<SolicitudTraspaso> _listaFiltrada = [];
  SolicitudTraspaso? _solicitudSeleccionada;
  bool _conErrorInicial = false;

  @override
  void initState() {
    super.initState();
    _cargarListaInicial();
    // Si viene un código inicial, hacer la consulta específica después de cargar la lista
    if (widget.codigoInicial != null && widget.codigoInicial!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consultarEspecif(widget.codigoInicial!.trim());
      });
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarListaInicial() async {
    setState(() {
      _cargando = true;
      _error = null;
      _listaTraspasos = [];
      _listaFiltrada = [];
      _conErrorInicial = false;
    });

    try {
      final lista = await widget.service.listarTraspasos();
      if (!mounted) return;
      setState(() {
        _listaTraspasos = lista;
        _listaFiltrada = lista;
        _cargando = false;
        // Si hay código inicial, consultar después de frame (ya lo hicimos en postFrameCallback)
        // Si no, mostramos la lista con el buscador visible
        if (widget.codigoInicial == null || widget.codigoInicial!.trim().isEmpty) {
          // Lista lista para mostrarse con buscador arriba
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      String mensajeError = e.message;
      if (e.codigo == 'SIN_PERMISO' || e.statusCode == 403) {
        mensajeError = 'No tienes permisos para ver las solicitudes de traspaso.';
      }
      setState(() {
        _error = mensajeError;
        _cargando = false;
        _conErrorInicial = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al cargar la lista de solicitudes.';
        _cargando = false;
        _conErrorInicial = true;
      });
    }
  }

  Future<void> _consultarEspecif([String? codigoParam]) async {
    final codigo = (codigoParam ?? _codigoCtrl.text).trim();
    if (codigo.isEmpty) {
      setState(() {
        _error = 'Por favor ingresa un código o ID de solicitud de traspaso.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
      // Limpiamos la selección anterior antes de la nueva consulta
      _solicitudSeleccionada = null;
      _listaFiltrada = [];
    });

    try {
      final res = await widget.service.consultarSeguimiento(codigo);
      if (!mounted) return;

      // 1. El resultado definitivo viene DEL SERVICIO, NO de la lista filtrada
      //    Esto asegura que mostremos exactamente lo que el backend devolvió
      setState(() {
        _solicitudSeleccionada = res;
        _cargando = false;
      });

      // 2. Filtrar la lista LOCAL solo para efectos de UI (mostrar "coincidencias" nearby)
      //    Pero NO usamos esta lista para el detalle - usamos _solicitudSeleccionada
      final codigoNormalizado = codigo.trim().toUpperCase();
      final listaFiltrada = _listaTraspasos.where((s) {
        final codigoLocalNormalizado = (s.codigo ?? '').trim().toUpperCase();
        return codigoLocalNormalizado.contains(codigoNormalizado) ||
            (s.producto ?? '').toUpperCase().contains(codigoNormalizado) ||
            (s.resumen ?? '').toUpperCase().contains(codigoNormalizado);
      }).toList();

      setState(() {
        _listaFiltrada = listaFiltrada;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      String mensajeError = e.message;
      if (e.codigo == 'SOLICITUD_NO_ENCONTRADA' || e.statusCode == 404) {
        mensajeError = 'No se encontró ninguna solicitud de traspaso con el código o ID "$codigo".';
      } else if (e.codigo == 'SIN_PERMISO' || e.statusCode == 403) {
        mensajeError = 'No tienes permisos para consultar esta solicitud (pertenece a otra sucursal o usuario).';
      }
      setState(() {
        _error = mensajeError;
        _cargando = false;
        _solicitudSeleccionada = null;
        _listaFiltrada = _listaTraspasos; // restaurar lista completa
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al consultar el seguimiento de la solicitud.';
        _cargando = false;
        _solicitudSeleccionada = null;
        _listaFiltrada = _listaTraspasos; // restaurar lista completa
      });
    }
  }

  Color _colorEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'APROBADO':
        return Colors.blue;
      case 'ENVIADO':
        return Colors.indigo;
      case 'RECIBIDO':
        return Colors.green;
      case 'CANCELADO':
        return Colors.red;
      case 'PENDIENTE':
      default:
        return Colors.orange;
    }
  }

  // Método para filtrar la lista por texto ingresado (búsqueda en código y producto)
  List<SolicitudTraspaso> _filtrarPorTexto(String texto) {
    if (texto.isEmpty) return _listaTraspasos;
    final lowercase = texto.toLowerCase();
    return _listaTraspasos.where((s) {
      final codigoMatch = s.codigo.toLowerCase().contains(lowercase);
      final productoMatch = (s.producto ?? '').toLowerCase().contains(lowercase);
      final resumenMatch = (s.resumen ?? '').toLowerCase().contains(lowercase);
      return codigoMatch || productoMatch || resumenMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // Si aún estamos cargando al inicio y hubo error, mostrar estado de error
    if (_cargando && _conErrorInicial && _listaTraspasos.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seguimiento de traspaso (CU28)'),
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si hay una solicitud específica seleccionada, mostrar su detalle
    if (_solicitudSeleccionada != null) {
      return _buildConDetalle(theme, textTheme, colorScheme);
    }

    // Modo normal: lista + buscador siempre visible
    return _buildConListaYBusqueda(theme, textTheme, colorScheme);
  }

  /// Pantalla completa: AppBar + Buscador fijo arriba + Lista debajo
  Widget _buildConListaYBusqueda(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de traspaso (CU28)'),
        // Removido el botón "Ver lista completa" - la lista se muestra por defecto
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. BUSCADOR SEMPRE VISIBLE EN LA PARTE SUPERIOR
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código o ID de solicitud',
                      hintText: 'Ej. TRP-20261101-0001 o número',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _consultarEspecif(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _cargando ? null : () => _consultarEspecif(),
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Consultar'),
                  //disabledColor: Colors.grey,
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. LISTA DE TRASPASSOS ABAJO DEL BUSCADOR
          // ==========================================
          Expanded(
            child: _buildListaTraspasosWidget(theme, textTheme, colorScheme),
          ),
        ],
      ),
    );
  }

  /// Listado de traspasos en tarjetas
  Widget _buildListaTraspasosWidget(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
    final listaMostrar = _listaFiltrada.isNotEmpty ? _listaFiltrada : _listaTraspasos;

    if (listaMostrar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _listaTraspasos.isEmpty
                  ? 'No hay solicitudes de traspaso registradas.'
                  : 'No se encontraron traspasos con los filtros aplicados.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresá un código o ID para buscar en la lista anterior.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: listaMostrar.length,
      itemBuilder: (context, index) {
        final s = listaMostrar[index];
        final colorEst = _colorEstado(s.estado);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              '${s.codigo} — ${s.producto ?? '—'}',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: Chip(
              label: Text(
                s.estado,
                style: TextStyle(color: colorEst, fontWeight: FontWeight.bold),
              ),
              backgroundColor: colorEst.withValues(alpha: 0.15),
              side: BorderSide(color: colorEst.withValues(alpha: 0.5)),
            ),
            onTap: () {
              _consultarEspecif(s.codigo);
            },
            subtitle: Text(
              'Origen: ${s.origen ?? '—'} | Destino: ${s.destino ?? '—'} | Cant: ${s.cantidad}',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ),
        );
      },
    );
  }

  /// Modo detalle: cuando se consulta un código específico
  Widget _buildConDetalle(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
    final s = _solicitudSeleccionada!;
    final colorEst = _colorEstado(s.estado);

    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitud ${s.codigo}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a la lista',
            onPressed: () {
              setState(() {
                _solicitudSeleccionada = null;
                _listaFiltrada = _listaTraspasos;
                _codigoCtrl.clear();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Solicitud ${s.codigo}',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        s.estado,
                        style: TextStyle(color: colorEst, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: colorEst.withValues(alpha: 0.15),
                      side: BorderSide(color: colorEst.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (s.resumen != null && s.resumen!.isNotEmpty) ...[
                  Text(
                    s.resumen!,
                    style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Detalles de la prenda', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
                const SizedBox(height: 8),
                _filaInfo('Prenda', s.variante ?? s.producto ?? '—'),
                if (s.sku != null) _filaInfo('SKU', s.sku!),
                if (s.talla != null) _filaInfo('Talla', s.talla!),
                if (s.color != null) _filaInfo('Color', s.color!),
                _filaInfo('Cantidad', '${s.cantidad}'),
                const Divider(height: 24),
                Text('Ruta del traspaso', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
                const SizedBox(height: 8),
                _filaInfo('Sucursal de origen', '${s.origen ?? '—'} (${s.ciudadOrigen ?? '—'})'),
                _filaInfo('Sucursal de destino', '${s.destino ?? '—'} (${s.ciudadDestino ?? '—'})'),
                const Divider(height: 24),
                Text('Información general', style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
                const SizedBox(height: 8),
                if (s.solicitante != null) _filaInfo('Solicitante', '${s.solicitante} (${s.solicitanteRol ?? '—'})'),
                if (s.fechaSolicitud != null) _filaInfo('Fecha de solicitud', s.fechaSolicitud!),
                if (s.motivo != null && s.motivo!.isNotEmpty) _filaInfo('Motivo', s.motivo!),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La consulta es informativa: no modifica el inventario ni el estado de la solicitud en la base de datos (CU28).',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _solicitudSeleccionada = null;
                      _listaFiltrada = _listaTraspasos;
                      _codigoCtrl.clear();
                    });
                  },
                  child: const Text('Volver a la lista de traspasos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaInfo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}