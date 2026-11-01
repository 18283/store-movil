import 'package:flutter/material.dart';

import '../../core/models/reserva.dart';
import 'reservas_service.dart';

/// CU17 — Consultar y cancelar reserva.
class MisReservasPage extends StatefulWidget {
  final ReservasService reservas;

  const MisReservasPage({super.key, required this.reservas});

  @override
  State<MisReservasPage> createState() => _MisReservasPageState();
}

class _MisReservasPageState extends State<MisReservasPage> {
  bool _cargando = true;
  List<Reserva> _reservas = [];
  int? _cancelando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await widget.reservas.mias();
      if (mounted) {
        setState(() {
          _reservas = res;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cancelar(Reserva r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text(
          '¿Cancelar esta reserva? El cupo y el stock se liberan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cancelando = r.id);
    try {
      final actualizada = await widget.reservas.cancelar(r.id);
      if (!mounted) return;
      setState(() {
        _reservas = _reservas
            .map((x) => x.id == actualizada.id ? actualizada : x)
            .toList();
        _cancelando = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
    } catch (_) {
      if (mounted) {
        setState(() => _cancelando = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar la reserva.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _reservas.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.event_note_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('Todavía no tenés reservas.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _reservas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _TarjetaReserva(
                  reserva: _reservas[i],
                  cancelando: _cancelando == _reservas[i].id,
                  onCancelar: () => _cancelar(_reservas[i]),
                ),
              ),
      ),
    );
  }
}

class _TarjetaReserva extends StatelessWidget {
  final Reserva reserva;
  final bool cancelando;
  final VoidCallback onCancelar;

  const _TarjetaReserva({
    required this.reserva,
    required this.cancelando,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${reserva.fecha}  ${reserva.horaInicio.substring(0, 5)}–${reserva.horaFin.substring(0, 5)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    etiquetaEstadoReserva[reserva.estado] ?? reserva.estado,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${reserva.sucursal} — ${reserva.ciudad}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...reserva.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.producto ?? ''} · ${item.talla ?? ''}/${item.color ?? ''} × ${item.cantidad}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (reserva.estado == 'PENDIENTE') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: cancelando ? null : onCancelar,
                  icon: const Icon(Icons.event_busy),
                  label: Text(cancelando ? 'Cancelando…' : 'Cancelar reserva'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
