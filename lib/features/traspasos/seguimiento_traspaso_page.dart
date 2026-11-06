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
/// Esta pantalla muestra inicialmente la lista completa de traspasos (como la versión web en Angular),
/// y permite filtrar por código específico o ID numérico.
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
  bool _mostrandoFormulario = true; // true = formulario de búsqueda, false = lista de resultados
  SolicitudTraspaso? _solicitudSeleccionada;

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
      _mostrandoFormulario = true;
    });

    try {
      final lista = await widget.service.listarTraspasos();
      if (!mounted) return;
      setState(() {
        _listaTraspasos = lista;
        _listaFiltrada = lista;
        _cargando = false;
        // Si ya venimos con un código inicial, ya lo consultamos en el postframe callback
        // Si no, mostramos la lista vacía o el mensaje inicial
        if (widget.codigoInicial == null || widget.codigoInicial!.trim().isEmpty) {
          _mostrandoFormulario = _listaFiltrada.isNotEmpty ? false : true;
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al cargar la lista de solicitudes.';
        _cargando = false;
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
    });

    try {
      final res = await widget.service.consultarSeguimiento(codigo);
      if (!mounted) return;
      setState(() {
        _solicitudSeleccionada = res;
        _cargando = false;
        _mostrandoFormulario = false;
        // Filtrar la lista para mostrar solo el encontrado
        _listaFiltrada = _listaTraspasos.where((s) => s.codigo == res.codigo).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      String mensajeError = e.message;
      if (e.codigo == 'SOLICITUD_NO_ENCONTRADA' || e.statusCode == 404) {
        mensajeError = 'No se encontró ninguna solicitud de traspaso con el código o ID "$codigo".';
        // Agregar mensaje de "no encontrado" a la lista filtrada para efectos visuales
        _listaFiltrada = [];
      } else if (e.codigo == 'SIN_PERMISO' || e.statusCode == 403) {
        mensajeError = 'No tienes permisos para consultar esta solicitud (pertenece a otra sucursal o usuario).';
        _listaFiltrada = [];
      }
      setState(() {
        _error = mensajeError;
        _cargando = false;
        _mostrandoFormulario = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al consultar el seguimiento de la solicitud.';
        _cargando = false;
        _mostrandoFormulario = true;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de traspaso (CU28)'),
        actions: [
          if (!_cargando && !_mostrandoFormulario)
            IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'Ver lista completa',
              onPressed: () {
                setState(() {
                  _mostrandoFormulario = true;
                  _listaFiltrada = _listaTraspasos;
                  _solicitudSeleccionada = null;
                  _codigoCtrl.clear();
                });
              },
            ),
        ],
      ),
      body: _buildBody(context, theme, textTheme, colorScheme),
    );
  }

  Widget _buildBody(
      BuildContext context,
      ThemeData theme,
      TextTheme textTheme,
      ColorScheme colorScheme,
      ) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
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
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Modo lista: mostrar todos los traspasos en un ListView
    if (_mostrandoFormulario && _solicitudSeleccionada == null) {
      return _buildListaTraspasos(theme, textTheme, colorScheme);
    }

    // Modo detalle: mostrar la solicitud específica encontrada
    if (_solicitudSeleccionada != null) {
      return _buildDetalleSolicitud(theme, textTheme, colorScheme);
    }

    // Fallback
    return const Center(child: Text('Sin datos disponibles'));
  }

  /// Builder de la lista de traspasos principal
  Widget _buildListaTraspasos(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
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
              'Ingresá un código o ID para buscar, o esperá a que cargue la lista completa.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
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
            // Subtítulo con origen/destino resumido
            subtitle: Text(
              'Origen: ${s.origen ?? '—'} | Destino: ${s.destino ?? '—'} | Cant: ${s.cantidad}',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ),
        );
      },
    );
  }

  /// Builder del detalle de una solicitud específica
  Widget _buildDetalleSolicitud(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
    final s = _solicitudSeleccionada!;
    final colorEst = _colorEstado(s.estado);

    return SingleChildScrollView(
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
                  Expanded(
                    child: Text(
                      'Solicitud ${s.codigo}',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
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
              FilledButton.icon(
                onPressed: () {
                  // Volver al modo lista
                  setState(() {
                    _solicitudSeleccionada = null;
                    _listaFiltrada = _listaTraspasos;
                    _codigoCtrl.clear();
                    _mostrandoFormulario = true;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver a la lista'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
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