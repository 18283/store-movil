import 'package:flutter/material.dart';

import '../../core/models/cambio.dart';
import 'cambios_service.dart';

/// CU23 — historial de cambios y devoluciones del cliente.
class MisCambiosPage extends StatefulWidget {
  final CambiosService cambios;

  const MisCambiosPage({super.key, required this.cambios});

  @override
  State<MisCambiosPage> createState() => _MisCambiosPageState();
}

class _MisCambiosPageState extends State<MisCambiosPage> {
  bool _cargando = true;
  List<Solicitud> _solicitudes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await widget.cambios.mias();
      if (mounted) {
        setState(() {
          _solicitudes = res;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis cambios y devoluciones')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _solicitudes.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Icon(Icons.sync_alt, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('No tenés solicitudes de cambio o devolución.')),
                  SizedBox(height: 4),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Desde "Mis compras" podés pedir un cambio de talla o una '
                        'devolución dentro de 48 horas.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _solicitudes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _TarjetaSolicitud(s: _solicitudes[i]),
              ),
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  final Solicitud s;

  const _TarjetaSolicitud({required this.s});

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
                    '${s.tipo == 'CAMBIO' ? 'Cambio' : 'Devolución'} — ${s.producto ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(_etiquetaCorta(s.estado)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Devolvés: ${s.varianteDevuelta ?? ''} × ${s.cantidad}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (s.varianteNueva != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Te llevás: ${s.varianteNueva}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.sucursal ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (s.estado == 'RESUELTO' && s.diferencia != null && s.diferencia != 0) ...[
              const SizedBox(height: 8),
              Text(
                s.diferencia! > 0
                    ? 'Pagaste una diferencia de Bs ${s.diferencia!.toStringAsFixed(2)}'
                    : 'Se te devolvieron Bs ${(-s.diferencia!).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: s.diferencia! < 0
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _etiquetaCorta(String estado) {
    switch (estado) {
      case 'SOLICITADO':
        return 'Solicitado';
      case 'RECIBIDO':
        return 'Recibido';
      case 'RESUELTO':
        return 'Resuelto';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return estado;
    }
  }
}
