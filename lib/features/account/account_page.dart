import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/network/api_exception.dart';
import '../../core/offline/tarjeta_service.dart';

/// CU2 — Mi cuenta: editar datos propios y cambiar contraseña.
/// También CU12/CU14 — tarjeta guardada, para comprar sin conexión.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with WidgetsBindingObserver {
  final _datosFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;

  final _passwordActualCtrl = TextEditingController();
  final _passwordNuevaCtrl = TextEditingController();
  final _passwordConfirmarCtrl = TextEditingController();

  bool _guardandoDatos = false;
  bool _cambiandoPassword = false;

  late final TarjetaService _tarjetaService;
  bool _esCliente = false;
  bool _tieneTarjeta = false;
  bool _cargandoTarjeta = true;
  bool _procesandoTarjeta = false;
  bool _esperandoVueltaDeStripe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthService>();
    final usuario = auth.usuario!;
    _nombreCtrl = TextEditingController(text: usuario.nombre);
    _apellidoCtrl = TextEditingController(text: usuario.apellido);
    _telefonoCtrl = TextEditingController(text: usuario.telefono ?? '');
    _esCliente = usuario.rol == 'Cliente';
    _tarjetaService = TarjetaService(auth.api);
    if (_esCliente) {
      _cargarEstadoTarjeta();
    } else {
      _cargandoTarjeta = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordActualCtrl.dispose();
    _passwordNuevaCtrl.dispose();
    _passwordConfirmarCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_esperandoVueltaDeStripe) return;
    _esperandoVueltaDeStripe = false;
    _confirmarTarjetaAlVolver();
  }

  Future<void> _cargarEstadoTarjeta() async {
    setState(() => _cargandoTarjeta = true);
    try {
      final estado = await _tarjetaService.estado();
      if (mounted) setState(() => _tieneTarjeta = estado.tieneTarjetaGuardada);
    } catch (_) {
      // Sin conexión: no es bloqueante acá, se reintenta más tarde.
    } finally {
      if (mounted) setState(() => _cargandoTarjeta = false);
    }
  }

  Future<void> _guardarTarjeta() async {
    setState(() => _procesandoTarjeta = true);
    try {
      final url = await _tarjetaService.iniciarGuardado();
      _esperandoVueltaDeStripe = true;
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      _mostrarMensaje('No se pudo iniciar el guardado de la tarjeta.');
    } finally {
      if (mounted) setState(() => _procesandoTarjeta = false);
    }
  }

  Future<void> _confirmarTarjetaAlVolver() async {
    setState(() => _procesandoTarjeta = true);
    try {
      final estado = await _tarjetaService.confirmar();
      if (mounted) setState(() => _tieneTarjeta = estado.tieneTarjetaGuardada);
      _mostrarMensaje(
        estado.tieneTarjetaGuardada
            ? 'Tarjeta guardada correctamente.'
            : 'Todavía no se confirmó el guardado de la tarjeta.',
      );
    } catch (_) {
      _mostrarMensaje('No se pudo confirmar la tarjeta.');
    } finally {
      if (mounted) setState(() => _procesandoTarjeta = false);
    }
  }

  Future<void> _eliminarTarjeta() async {
    setState(() => _procesandoTarjeta = true);
    try {
      final estado = await _tarjetaService.eliminar();
      if (mounted) setState(() => _tieneTarjeta = estado.tieneTarjetaGuardada);
      _mostrarMensaje('Tarjeta eliminada.');
    } catch (_) {
      _mostrarMensaje('No se pudo eliminar la tarjeta.');
    } finally {
      if (mounted) setState(() => _procesandoTarjeta = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _guardarDatos() async {
    if (!_datosFormKey.currentState!.validate()) return;

    setState(() => _guardandoDatos = true);
    try {
      await context.read<AuthService>().actualizarMiCuenta(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
      );
      _mostrarMensaje('Datos actualizados');
    } on ApiException catch (e) {
      _mostrarMensaje(e.message);
    } finally {
      if (mounted) setState(() => _guardandoDatos = false);
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _cambiandoPassword = true);
    try {
      await context.read<AuthService>().cambiarPassword(
        actual: _passwordActualCtrl.text,
        nueva: _passwordNuevaCtrl.text,
      );
      _passwordActualCtrl.clear();
      _passwordNuevaCtrl.clear();
      _passwordConfirmarCtrl.clear();
      _mostrarMensaje('Contraseña actualizada');
    } on ApiException catch (e) {
      _mostrarMensaje(e.message);
    } finally {
      if (mounted) setState(() => _cambiandoPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mis datos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _datosFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'Muy corto' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ? 'Muy corto' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _guardandoDatos ? null : _guardarDatos,
                    child: _guardandoDatos
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar datos'),
                  ),
                ],
              ),
            ),
            if (_esCliente) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Tarjeta guardada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Necesaria para comprar sin conexión (CU12): se cobra sola apenas vuelve internet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_cargandoTarjeta)
                const Center(child: CircularProgressIndicator())
              else if (_tieneTarjeta) ...[
                const Row(
                  children: [
                    Icon(Icons.credit_card),
                    SizedBox(width: 8),
                    Text('Tenés una tarjeta guardada.'),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _procesandoTarjeta ? null : _eliminarTarjeta,
                  child: const Text('Quitar tarjeta'),
                ),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.credit_card_off),
                    SizedBox(width: 8),
                    Expanded(child: Text('Todavía no guardaste ninguna tarjeta.')),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _procesandoTarjeta ? null : _guardarTarjeta,
                  child: _procesandoTarjeta
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar tarjeta'),
                ),
              ],
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Cambiar contraseña',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passwordActualCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordNuevaCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña nueva',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordConfirmarCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña nueva',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != _passwordNuevaCtrl.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _cambiandoPassword ? null : _cambiarPassword,
                    child: _cambiandoPassword
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cambiar contraseña'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
