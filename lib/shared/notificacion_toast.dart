import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/notificacion_service.dart';

class NotificacionToast extends StatefulWidget {
  final NotificacionService service;
  final Widget child;

  const NotificacionToast({
    super.key,
    required this.service,
    required this.child,
  });

  @override
  State<NotificacionToast> createState() => _NotificacionToastState();
}

class _NotificacionToastState extends State<NotificacionToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onNotificacionCambiada);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.service.removeListener(_onNotificacionCambiada);
    super.dispose();
  }

  void _onNotificacionCambiada() {
    _timer?.cancel();
    if (widget.service.actual != null) {
      _timer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          widget.service.limpiar();
        }
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.service.actual;
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,
        if (notif != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, -20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: notif.tipo == 'error'
                        ? theme.colorScheme.error
                        : notif.tipo == 'info'
                            ? theme.colorScheme.primary
                            : Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notif.tipo == 'error'
                            ? Icons.error_outline
                            : notif.tipo == 'info'
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notif.mensaje,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => widget.service.limpiar(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
