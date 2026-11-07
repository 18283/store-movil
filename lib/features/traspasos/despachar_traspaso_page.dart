import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/traspaso.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/notificacion_service.dart';
import 'traspasos_service.dart';

class DespacharTraspasoPage extends StatefulWidget {
  final TraspasosService service;

  const DespacharTraspasoPage({super.key, required this.service});

  @override
  State<DespacharTraspasoPage> createState() => _DespacharTraspasoPageState();
}

class _DespacharTraspasoPageState extends State<DespacharTraspasoPage> {
  bool _cargando = true;
  String? _error;
  List<SolicitudTraspaso> _traspasos = [];
  int? _procesandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await widget.service.listarTraspasos();
      final pendientes = lista.where((s) => s.estado == 'PENDIENTE' || s.estado == 'APROBADO').toList();
      if (!mounted) return;
      setState(() {
        _traspasos = pendientes;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las solicitudes para despachar.';
        _cargando = false;
      });
    }
  }

  Future<void> _despachar(SolicitudTraspaso s) async {
    if (s.id == null) return;
    setState(() => _procesandoId = s.id);
    try {
      final actualizada = await widget.service.despachar(s.id!);
      if (!mounted) return;

      context.read<NotificacionService>().mostrar(
            'Solicitud ${actualizada.codigo} ha sido EN_TRANSITO',
            'success',
          );

      await _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() => _procesandoId = null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo despachar el traspaso.'), backgroundColor: Colors.red),
      );
      setState(() => _procesandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despachar traspasos'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _traspasos.isEmpty
                  ? Center(
                      child: Text(
                        'No hay solicitudes pendientes o aprobadas para despachar.',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _traspasos.length,
                      itemBuilder: (context, index) {
                        final s = _traspasos[index];
                        final procesando = _procesandoId == s.id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.between,
                                  children: [
                                    Text(
                                      s.codigo,
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text(s.estado),
                                      backgroundColor: Colors.orange.shade100,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Prenda: ${s.variante ?? s.producto ?? '—'}'),
                                Text('Origen: ${s.origen ?? '—'} → Destino: ${s.destino ?? '—'}'),
                                Text('Cantidad: ${s.cantidad}'),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: procesando ? null : () => _despachar(s),
                                    icon: procesando
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.local_shipping),
                                    label: Text(procesando ? 'Despachando…' : 'Despachar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
