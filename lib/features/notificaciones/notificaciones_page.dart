import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/models/notificacion.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/notificacion_service.dart';
import '../traspasos/seguimiento_traspaso_page.dart';
import '../traspasos/traspasos_service.dart';

/// CU29 / CU35 — Centro de Notificaciones.
///
/// Accesible desde la campanita del AppBar y desde el menú de la cuenta
/// (todos los roles). Lista paginada ordenada por fecha descendente y,
/// solo para Administrador, formulario de envío masivo.
class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  static const int _size = 20;

  final ScrollController _scrollCtrl = ScrollController();
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _tieneMas = true;
  int _page = 1;
  String? _error;
  bool _marcandoTodas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
    // Paginación: cargar la siguiente página al llegar al final.
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >
          _scrollCtrl.position.maxScrollExtent - 200) {
        _cargarSiguiente();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _page = 1;
      _tieneMas = true;
    });
    try {
      final antes = context.read<NotificacionService>().notificaciones.length;
      final lista = await context
          .read<NotificacionService>()
          .cargarNotificaciones(page: _page, size: _size);
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _tieneMas = lista.length - antes >= _size;
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
        _error = 'No se pudieron cargar las notificaciones.';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarSiguiente() async {
    if (_cargando || _cargandoMas || !_tieneMas) return;
    setState(() => _cargandoMas = true);
    try {
      final antes = context.read<NotificacionService>().notificaciones.length;
      final lista = await context
          .read<NotificacionService>()
          .cargarNotificaciones(page: _page + 1, size: _size, append: true);
      if (!mounted) return;
      setState(() {
        _page++;
        _cargandoMas = false;
        _tieneMas = lista.length - antes >= _size;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoMas = false);
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
    final rol = context.watch<AuthService>().usuario?.rol;
    final esAdmin = rol == 'Administrador' || rol == 'Admin';

    final itemExtra = _cargandoMas || _tieneMas ? 1 : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Notificaciones'),
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
      body: Column(
        children: [
          // CU35 — Envío masivo, solo para Administrador.
          if (esAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _mostrarFormularioMasivo(context),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar notificación masiva'),
                ),
              ),
            ),
          Expanded(
            child: _cargando && lista.isEmpty
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
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(12),
                            itemCount: lista.length + itemExtra,
                            itemBuilder: (context, index) {
                              if (index >= lista.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
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
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(_formatearFecha(n.fecha)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (n.modulo != null && n.modulo!.trim().isNotEmpty)
                                            Chip(
                                              label: Text(n.modulo!.trim()),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                            ),
                                          if (n.codigoTraspaso != null && n.codigoTraspaso!.trim().isNotEmpty)
                                            Chip(
                                              label: Text(n.codigoTraspaso!.trim()),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                            ),
                                          Chip(
                                            label: Text(n.leida ? 'Leída' : 'Sin leer'),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
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
          ),
        ],
      ),
    );
  }

  /// CU35 — Formulario de envío masivo (solo Administrador).
  void _mostrarFormularioMasivo(BuildContext context) {
    final mensajeCtrl = TextEditingController();
    String tipo = 'info';
    final rolesSeleccionados = <String>{};
    bool enviando = false;
    String? errorForm;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> enviar() async {
              final mensaje = mensajeCtrl.text.trim();
              if (mensaje.isEmpty) {
                setDialogState(() => errorForm = 'El mensaje no puede estar vacío.');
                return;
              }
              if (rolesSeleccionados.isEmpty) {
                setDialogState(() => errorForm = 'Seleccioná al menos un rol destino.');
                return;
              }

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(dialogContext);
              setDialogState(() {
                enviando = true;
                errorForm = null;
              });

              try {
                final enviados = await context.read<NotificacionService>().enviarMasiva(
                      mensaje: mensaje,
                      tipo: tipo,
                      rolesDestino: rolesSeleccionados.toList(),
                    );
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(enviados == 0
                        ? 'No se enviaron notificaciones (sin destinatarios válidos).'
                        : '$enviados notificaciones enviadas'),
                    duration: const Duration(seconds: 4),
                  ),
                );
                mensajeCtrl.clear();
                rolesSeleccionados.clear();
                _cargar();
              } on ApiException catch (e) {
                if (!mounted) return;
                String mensajeError = e.message;
                if (e.statusCode == 403) {
                  mensajeError = 'No tienes permiso para enviar notificaciones masivas (requiere Administrador).';
                } else if (e.statusCode == 422) {
                  mensajeError = 'Los datos enviados no son válidos. Revisá los campos e intentá de nuevo.';
                }
                setDialogState(() {
                  enviando = false;
                  errorForm = mensajeError;
                });
              } catch (_) {
                if (!mounted) return;
                setDialogState(() {
                  enviando = false;
                  errorForm = 'No se pudo enviar la notificación masiva.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Enviar notificación masiva'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: mensajeCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Máx. 500 caracteres', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(value: 'warning', child: Text('Aviso')),
                        DropdownMenuItem(value: 'success', child: Text('Éxito')),
                      ],
                      onChanged: (val) => setDialogState(() => tipo = val ?? 'info'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Roles destino', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...['Cliente', 'Encargado', 'Cajero'].map(
                      (rol) => CheckboxListTile(
                        title: Text(rol),
                        value: rolesSeleccionados.contains(rol),
                        onChanged: (val) => setDialogState(() {
                          if (val == true) {
                            rolesSeleccionados.add(rol);
                          } else {
                            rolesSeleccionados.remove(rol);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    if (errorForm != null) ...[
                      const SizedBox(height: 8),
                      Text(errorForm!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: enviando ? null : enviar,
                  child: enviando ? const Text('Enviando…') : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
