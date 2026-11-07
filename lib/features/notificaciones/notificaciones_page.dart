import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/models/notificacion.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/notificacion_service.dart';
import '../traspasos/seguimiento_traspaso_page.dart';
import '../traspasos/traspasos_service.dart';

/// CU29 / CU35 — Consultar notificaciones de traspaso.
class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  bool _cargando = true;
  String? _error;
  bool _marcandoTodas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await context.read<NotificacionService>().cargarNotificaciones();
      if (!mounted) return;
      setState(() => _cargando = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las notificaciones.';
        _cargando = false;
      });
    }
  }

  Future<void> _marcarTodas() async {
    setState(() => _marcandoTodas = true);
    try {
      await context.read<NotificacionService>().marcarTodasComoLeidas();
    } catch (_) {
      // El servicio ya conserva la actualización local.
    }
    if (!mounted) return;
    setState(() => _marcandoTodas = false);
  }

  Future<void> _onTap(Notificacion notif) async {
    final service = context.read<NotificacionService>();
    if (!notif.leida) {
      await service.marcarComoLeida(notif.id);
    }
    final codigo = notif.codigoTraspaso;
    if (codigo != null && codigo.trim().isNotEmpty && mounted) {
      final auth = context.read<AuthService>();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeguimientoTraspasoPage(
            service: TraspasosService(auth.api),
            codigoInicial: codigo.trim(),
          ),
        ),
      );
    }
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'error':
        return Icons.error_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _color(String tipo) {
    switch (tipo) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.amber.shade800;
      case 'error':
        return Colors.red;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  String _formatearFecha(DateTime f) {
    final dd = f.day.toString().padLeft(2, '0');
    final mm = f.month.toString().padLeft(2, '0');
    final hh = f.hour.toString().padLeft(2, '0');
    final min = f.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${f.year} $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final service = context.watch<NotificacionService>();
    final lista = service.notificaciones;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
          ),
          IconButton(
            icon: _marcandoTodas
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: (_marcandoTodas || service.noLeidas == 0) ? null : _marcarTodas,
          ),
        ],
      ),
      body: _cargando && lista.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && lista.isEmpty
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
              : lista.isEmpty
                  ? Center(
                      child: Text(
                        'No tenés notificaciones nuevas.',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: lista.length,
                      itemBuilder: (context, index) {
                        final n = lista[index];
                        final color = _color(n.tipo);
                        return Card(
                          color: n.leida ? null : colorScheme.primaryContainer.withValues(alpha: 0.35),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(_icono(n.tipo), color: color),
                            title: Text(
                              n.mensaje,
                              style: TextStyle(
                                fontWeight: n.leida ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_formatearFecha(n.fecha)),
                            trailing: n.leida
                                ? null
                                : Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () => _onTap(n),
                          ),
                        );
                      },
                    ),
    );
  }
}
