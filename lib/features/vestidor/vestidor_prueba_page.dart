import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';

import 'prenda_ar.dart';
import 'vestidor_camara_page.dart';

/// CU20 — Vestidor virtual (modo foto): el cliente toma o elige una foto, ML
/// Kit detecta los hombros y la prenda elegida se coloca encima. El cliente
/// puede afinar la posición arrastrando y el tamaño pellizcando.
class VestidorPruebaPage extends StatefulWidget {
  /// [prendas]: prendas a probar (por defecto las de demostración de la app).
  /// [inicial]: prenda que se muestra al abrir (por defecto la primera).
  const VestidorPruebaPage({super.key, this.prendas, this.inicial});

  final List<PrendaAr>? prendas;
  final PrendaAr? inicial;

  @override
  State<VestidorPruebaPage> createState() => _VestidorPruebaPageState();
}

class _VestidorPruebaPageState extends State<VestidorPruebaPage> {
  final _picker = ImagePicker();
  // Modo "single": pensado para fotos fijas (más preciso que el modo stream).
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );

  File? _foto;
  Size? _tamanoFoto;
  Pose? _pose;
  bool _procesando = false;
  String? _mensaje;

  late final List<PrendaAr> _prendas = widget.prendas ?? prendasDemo;
  late PrendaAr _prenda = widget.inicial ?? _prendas.first;
  bool _verPuntos = false;

  // Tamaño real (px) de las imágenes que vienen por URL, y las que fallaron.
  final Map<String, Size> _tamanos = {};
  final Set<String> _cargando = {};
  final Set<String> _conError = {};

  // La detección de hombros tiene ruido de un par de grados: una inclinación
  // menor a este umbral se toma como error de medición y no se aplica.
  static const _zonaMuerta = 6 * math.pi / 180;

  // Ajuste manual del cliente, aplicado encima del cálculo automático.
  Offset _desplazamiento = Offset.zero;
  double _escalaAjuste = 1;
  double _escalaBase = 1;
  double _giroAjuste = 0;
  double _giroBase = 0;

  bool get _ajustado =>
      _desplazamiento != Offset.zero || _escalaAjuste != 1 || _giroAjuste != 0;

  @override
  void initState() {
    super.initState();
    _cargarTamano(_prenda);
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }

  /// Tamaño en píxeles de la imagen de la prenda (null si aún no se conoce).
  Size? _tamanoPrenda(PrendaAr p) {
    if (p.ancho != null && p.alto != null) return Size(p.ancho!, p.alto!);
    return _tamanos[p.clave];
  }

  /// Descarga la imagen de una prenda por URL para conocer su tamaño real.
  void _cargarTamano(PrendaAr p) {
    final url = p.url;
    if (url == null ||
        _tamanos.containsKey(p.clave) ||
        _cargando.contains(p.clave)) {
      return;
    }
    _cargando.add(p.clave);
    _conError.remove(p.clave);
    final flujo = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener oyente;
    oyente = ImageStreamListener(
      (info, _) {
        flujo.removeListener(oyente);
        _cargando.remove(p.clave);
        if (!mounted) return;
        setState(() {
          _tamanos[p.clave] = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (_, _) {
        flujo.removeListener(oyente);
        _cargando.remove(p.clave);
        if (!mounted) return;
        setState(() => _conError.add(p.clave));
      },
    );
    flujo.addListener(oyente);
  }

  void _restablecerAjuste() {
    setState(() {
      _desplazamiento = Offset.zero;
      _escalaAjuste = 1;
      _giroAjuste = 0;
    });
  }

  Future<void> _elegir(ImageSource origen) async {
    final archivo = await _picker.pickImage(
      source: origen,
      preferredCameraDevice: CameraDevice.front,
      // Reducir la foto acelera la detección y no pierde precisión útil.
      maxWidth: 1080,
      imageQuality: 90,
    );
    if (archivo == null) return;

    setState(() {
      _foto = File(archivo.path);
      _tamanoFoto = null;
      _pose = null;
      _mensaje = null;
      _procesando = true;
      _desplazamiento = Offset.zero;
      _escalaAjuste = 1;
      _giroAjuste = 0;
    });

    try {
      // Tamaño real de la imagen ya orientada: sirve para escalar los puntos.
      final bytes = await archivo.readAsBytes();
      final imagen = await decodeImageFromList(bytes);
      final tamano = Size(imagen.width.toDouble(), imagen.height.toDouble());

      final poses = await _detector.processImage(
        InputImage.fromFilePath(archivo.path),
      );
      if (!mounted) return;
      setState(() {
        _tamanoFoto = tamano;
        _pose = poses.isEmpty ? null : poses.first;
        _mensaje = poses.isEmpty
            ? 'No se detectó a nadie. Probá con una foto de frente, con los '
                  'hombros y el torso visibles.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = 'Error al analizar la foto: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Matriz que lleva la imagen de la prenda hasta los hombros de la foto.
  ///
  /// Se compone de derecha a izquierda:
  ///  1. mover el centro de los hombros de la prenda al origen,
  ///  2. escalar (distancia entre hombros detectados / distancia entre las
  ///     anclas de la prenda),
  ///  3. rotar (inclinación de los hombros detectados),
  ///  4. mover al centro de los hombros detectados (más el ajuste manual).
  Matrix4? _matriz(Size visor) {
    final pose = _pose;
    final tamano = _tamanoFoto;
    if (pose == null || tamano == null) return null;
    final izq = pose.landmarks[PoseLandmarkType.leftShoulder];
    final der = pose.landmarks[PoseLandmarkType.rightShoulder];
    if (izq == null || der == null) return null;

    // De píxeles de la foto a píxeles en pantalla.
    final k = visor.width / tamano.width;
    var a = Offset(izq.x * k, izq.y * k);
    var b = Offset(der.x * k, der.y * k);
    // De frente, el hombro "izquierdo" de la persona queda a la derecha de la
    // imagen; se ordenan por posición para no depender de ese detalle.
    if (a.dx > b.dx) {
      final t = a;
      a = b;
      b = t;
    }

    final prenda = _prenda;
    final tamanoPrenda = _tamanoPrenda(prenda);
    if (tamanoPrenda == null) return null; // la imagen aún no se descargó
    // Las anclas vienen como fracción (0 a 1); se pasan a píxeles de la imagen.
    Offset aPx(Offset f) =>
        Offset(f.dx * tamanoPrenda.width, f.dy * tamanoPrenda.height);
    final anclaIzq = aPx(prenda.hombroIzq);
    final anclaDer = aPx(prenda.hombroDer);
    final entreHombros = b - a;
    final entreAnclas = anclaDer - anclaIzq;

    final escala =
        entreHombros.distance / entreAnclas.distance * _escalaAjuste;
    var inclinacion = entreHombros.direction - entreAnclas.direction;
    if (inclinacion.abs() < _zonaMuerta) inclinacion = 0;
    final angulo = inclinacion + _giroAjuste;
    final centro = (a + b) / 2 + _desplazamiento;
    final centroPrenda = (anclaIzq + anclaDer) / 2;

    return Matrix4.translationValues(centro.dx, centro.dy, 0) *
        Matrix4.rotationZ(angulo) *
        Matrix4.diagonal3Values(escala, escala, 1) *
        Matrix4.translationValues(-centroPrenda.dx, -centroPrenda.dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    final tamano = _tamanoFoto;
    final pose = _pose;

    return Scaffold(
      appBar: AppBar(title: const Text('Vestidor virtual')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Prueba la cámara en vivo o elige una foto de tu galería. '
              'Mantén ambos hombros y el torso visibles.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VestidorCamaraPage(
                              prendas: _prendas, inicial: _prenda),
                          )),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Cámara en vivo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _elegir(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_procesando) const Center(child: CircularProgressIndicator()),
            if (_mensaje != null)
              Text(
                _mensaje!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (foto != null && tamano != null) ...[
              if (pose != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final p in _prendas)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: p.color),
                        label: Text(p.nombre),
                        selected: p.clave == _prenda.clave,
                        onSelected: (_) {
                          setState(() => _prenda = p);
                          _cargarTamano(p);
                        },
                      ),
                  ],
                ),
                if (_conError.contains(_prenda.clave))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No se pudo cargar la imagen de la prenda. '
                      'Revisa tu conexión e intenta de nuevo.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else if (_cargando.contains(_prenda.clave))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: tamano.width / tamano.height,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final visor = Size(c.maxWidth, c.maxHeight);
                      final matriz = _matriz(visor);
                      return GestureDetector(
                        onScaleStart: (_) {
                          _escalaBase = _escalaAjuste;
                          _giroBase = _giroAjuste;
                        },
                        onScaleUpdate: (d) => setState(() {
                          _desplazamiento += d.focalPointDelta;
                          _escalaAjuste = (_escalaBase * d.scale)
                              .clamp(0.5, 2.0)
                              .toDouble();
                          _giroAjuste = _giroBase + d.rotation;
                        }),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(foto, fit: BoxFit.fill),
                            if (matriz != null)
                              Positioned(
                                left: 0,
                                top: 0,
                                width: _tamanoPrenda(_prenda)!.width,
                                height: _tamanoPrenda(_prenda)!.height,
                                child: IgnorePointer(
                                  child: Transform(
                                    transform: matriz,
                                    child: _prenda.asset != null
                                        ? Image.asset(
                                            _prenda.asset!,
                                            fit: BoxFit.fill,
                                          )
                                        : Image.network(
                                            _prenda.url!,
                                            fit: BoxFit.fill,
                                          ),
                                  ),
                                ),
                              ),
                            if (_verPuntos && pose != null)
                              CustomPaint(
                                painter: _PosePainter(
                                  pose: pose,
                                  imagen: tamano,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (pose != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Arrastra para mover, pellizca para el tamaño y gira '
                        'con dos dedos para inclinar.',
                      ),
                    ),
                    if (_ajustado)
                      TextButton(
                        onPressed: _restablecerAjuste,
                        child: const Text('Restablecer'),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar puntos detectados'),
                  value: _verPuntos,
                  onChanged: (v) => setState(() => _verPuntos = v),
                ),
                if (_verPuntos) _Resumen(pose: pose, tamano: tamano),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Dibuja los puntos del cuerpo y el contorno del torso sobre la foto.
class _PosePainter extends CustomPainter {
  _PosePainter({required this.pose, required this.imagen});

  final Pose pose;
  final Size imagen;

  @override
  void paint(Canvas canvas, Size size) {
    // ML Kit devuelve coordenadas en píxeles de la imagen original; la foto
    // se muestra a otro tamaño, así que se escala cada punto.
    final sx = size.width / imagen.width;
    final sy = size.height / imagen.height;
    Offset punto(PoseLandmark l) => Offset(l.x * sx, l.y * sy);

    final puntos = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final l in pose.landmarks.values) {
      canvas.drawCircle(punto(l), 4, puntos);
    }

    final torso = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftHip,
    ].map((t) => pose.landmarks[t]).toList();
    if (torso.any((l) => l == null)) return;

    final borde = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final camino = Path()..addPolygon(torso.map((l) => punto(l!)).toList(), true);
    canvas.drawPath(camino, borde);

    final hombro = Paint()..color = Colors.redAccent;
    canvas.drawCircle(punto(torso[0]!), 8, hombro);
    canvas.drawCircle(punto(torso[1]!), 8, hombro);
  }

  @override
  bool shouldRepaint(_PosePainter old) =>
      old.pose != pose || old.imagen != imagen;
}

/// Datos numéricos de la detección, para comprobar que es confiable.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.pose, required this.tamano});

  final Pose? pose;
  final Size tamano;

  String _confianza(PoseLandmarkType tipo) {
    final l = pose?.landmarks[tipo];
    return l == null ? '—' : '${(l.likelihood * 100).round()} %';
  }

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    final izq = pose?.landmarks[PoseLandmarkType.leftShoulder];
    final der = pose?.landmarks[PoseLandmarkType.rightShoulder];
    final ancho = (izq != null && der != null)
        ? (izq.x - der.x).abs().round()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foto: ${tamano.width.round()} × ${tamano.height.round()} px',
              style: estilo,
            ),
            Text(
              'Ancho de hombros: ${ancho != null ? '$ancho px' : '—'}',
              style: estilo,
            ),
            const SizedBox(height: 8),
            Text(
              'Confianza — hombro izq.: ${_confianza(PoseLandmarkType.leftShoulder)}'
              ' · der.: ${_confianza(PoseLandmarkType.rightShoulder)}',
              style: estilo,
            ),
            Text(
              'Confianza — cadera izq.: ${_confianza(PoseLandmarkType.leftHip)}'
              ' · der.: ${_confianza(PoseLandmarkType.rightHip)}',
              style: estilo,
            ),
          ],
        ),
      ),
    );
  }
}
