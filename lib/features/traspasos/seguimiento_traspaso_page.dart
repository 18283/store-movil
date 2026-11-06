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
  SolicitudTraspaso? _solicitud;

  @override
  void initState() {
    super.initState();
    if (widget.codigoInicial != null && widget.codigoInicial!.trim().isNotEmpty) {
      _codigoCtrl.text = widget.codigoInicial!.trim();
      _consultar(widget.codigoInicial!.trim());
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _consultar([String? codigoParam]) async {
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
      _solicitud = null;
    });

    try {
      final res = await widget.service.consultarSeguimiento(codigo);
      if (!mounted) return;
      setState(() {
        _solicitud = res;
        _cargando = false;
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al consultar el seguimiento de la solicitud.';
        _cargando = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de traspaso (CU28)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Consultá el estado actual y detalles de cualquier solicitud de traspaso ingresando su código o ID numérico (CU28).',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código o ID de solicitud',
                    hintText: 'Ej. TRP-20261101-0001 o 1',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _consultar(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _cargando ? null : () => _consultar(),
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: const Text('Consultar'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_solicitud != null) ...[
            const SizedBox(height: 24),
            _buildDetalleSolicitud(theme, textTheme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildDetalleSolicitud(ThemeData theme, TextTheme textTheme, ColorScheme colorScheme) {
    final s = _solicitud!;
    final colorEst = _colorEstado(s.estado);

    return Card(
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
          ],
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
