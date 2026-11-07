import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/traspaso.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/notificacion_service.dart';
import 'traspasos_service.dart';

class ConfirmarRecepcionPage extends StatefulWidget {
  final TraspasosService service;

  const ConfirmarRecepcionPage({super.key, required this.service});

  @override
  State<ConfirmarRecepcionPage> createState() => _ConfirmarRecepcionPageState();
}

class _ConfirmarRecepcionPageState extends State<ConfirmarRecepcionPage> {
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
      final enTransito = lista.where((s) => s.estado == 'ENVIADO' || s.estado == 'EN_TRANSITO').toList();
      if (!mounted) return;
      setState(() {
        _traspasos = enTransito;
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
        _error = 'No se pudieron cargar las solicitudes para confirmar recepción.';
        _cargando = false;
      });
    }
  }

  Future<void> _recibir(SolicitudTraspaso s) async {
    if (s.id == null) return;
    setState(() => _procesandoId = s.id);
    try {
      final actualizada = await widget.service.recibir(s.id!);
      if (!mounted) return;

      context.read<NotificacionService>().mostrar(
            'Solicitud ${actualizada.codigo} ha sido RECIBIDO',
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
        const SnackBar(content: Text('No se pudo confirmar la recepción.'), backgroundColor: Colors.red),
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
        title: const Text('Confirmar recepción de traspasos'),
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
                        'No hay solicitudes en tránsito para recibir.',
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
                                      backgroundColor: Colors.indigo.shade100,
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
                                    onPressed: procesando ? null : () => _recibir(s),
                                    icon: procesando
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.check_circle_outline),
                                    label: Text(procesando ? 'Recibiendo…' : 'Confirmar recepción'),
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
