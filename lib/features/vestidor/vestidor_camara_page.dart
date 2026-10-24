import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:http/http.dart' as http;

import 'geometria_vestidor.dart';
import 'prenda_ar.dart';

/// CU20: seguimiento local en Android. La galeria sigue en su pantalla original.
class VestidorCamaraPage extends StatefulWidget {
  const VestidorCamaraPage({
    super.key,
    required this.prendas,
    required this.inicial,
  });
  final List<PrendaAr> prendas;
  final PrendaAr inicial;

  @override
  State<VestidorCamaraPage> createState() => _VestidorCamaraPageState();
}

class _VestidorCamaraPageState extends State<VestidorCamaraPage>
    with WidgetsBindingObserver {
  CameraController? _camara;
  PoseDetector? _detector;
  List<CameraDescription> _camaras = [];
  int _indice = 0;
  bool _cerrado = false;
  bool _activo = true;
  bool _iniciando = true;
  bool _verPuntos = false;
  int _generacion = 0;
  int _errores = 0;
  String? _errorCamara;
  String? _errorPrenda;
  Future<void> _operaciones = Future.value();
  Future<void>? _deteccion;
  DateTime _ultimoFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _ultimaPose = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _vigilarPose;
  Map<PoseLandmarkType, Offset> _puntos = {};
  bool _torso = false;
  late PrendaAr _prenda = widget.inicial;
  final Map<String, ui.Image> _imagenes = {};
  final Set<String> _cargando = {};

  bool get _visible => mounted && !_cerrado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarPrenda(_prenda);
    _programarCamara();
    _vigilarPose = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_visible &&
          _puntos.isNotEmpty &&
          DateTime.now().difference(_ultimaPose).inMilliseconds > 750) {
        setState(() {
          _puntos = {};
          _torso = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _activo = state == AppLifecycleState.resumed;
    _programarCamara();
  }

  // Serializa abrir/cerrar para evitar carreras al pausar, volver o cambiar lente.
  void _programarCamara() {
    _generacion++;
    _operaciones = _operaciones
        .then((_) async {
          await _pararCamara();
          if (_cerrado || !_activo) return;
          await _iniciarCamara();
        })
        .catchError((Object e) {
          if (_visible) {
            setState(() {
              _iniciando = false;
              _errorCamara =
                  'No se pudo iniciar la cámara. Revisa el permiso y reintenta.';
            });
          }
        });
  }

  Future<void> _pararCamara() async {
    final camara = _camara;
    _camara = null;
    if (_visible) {
      setState(() {
        _puntos = {};
        _torso = false;
      });
    }
    if (camara != null) {
      try {
        if (camara.value.isStreamingImages) await camara.stopImageStream();
      } on CameraException catch (_) {
        /* Puede estar ya cerrada por Android. */
      }
      await camara.dispose();
    }
    // No cerrar ML Kit mientras una inferencia nativa siga en curso.
    await _deteccion;
    final detector = _detector;
    _detector = null;
    await detector?.close();
  }

  Future<void> _iniciarCamara() async {
    final generacion = _generacion;
    if (_visible) {
      setState(() {
        _iniciando = true;
        _errorCamara = null;
        _errores = 0;
      });
    }
    if (!Platform.isAndroid) {
      if (_visible) {
        setState(() {
          _iniciando = false;
          _errorCamara =
              'El modo en vivo esta disponible en Android. Puedes usar Galería.';
        });
      }
      return;
    }
    CameraController? nueva;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (_camaras.isEmpty) {
        _camaras = (await availableCameras())
            .where((c) => c.lensDirection != CameraLensDirection.external)
            .toList();
        final frontal = _camaras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _indice = frontal < 0 ? 0 : frontal;
      }
      if (_camaras.isEmpty) throw StateError('No hay cámaras');
      nueva = CameraController(
        _camaras[_indice],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await nueva.initialize();
      await nueva.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!_visible || !_activo || generacion != _generacion) {
        await nueva.dispose();
        return;
      }
      _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );
      _camara = nueva;
      await nueva.startImageStream(_recibirFrame);
      if (_visible) setState(() => _iniciando = false);
    } catch (e) {
      if (identical(_camara, nueva)) _camara = null;
      await nueva?.dispose();
      await _detector?.close();
      _detector = null;
      if (_visible) {
        setState(() {
          _iniciando = false;
          _errorCamara =
              e is CameraException && e.code.startsWith('CameraAccess')
              ? 'Permite el acceso a la cámara en los ajustes del teléfono y reintenta.'
              : 'No se pudo abrir la cámara. Cierra otras apps que la usen y reintenta.';
        });
      }
    }
  }

  void _recibirFrame(CameraImage frame) {
    if (_cerrado || !_activo || _deteccion != null || _errorCamara != null) {
      return;
    }
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoFrame).inMilliseconds < 80) return;
    final camara = _camara;
    final detector = _detector;
    if (camara == null || detector == null) return;
    _ultimoFrame = ahora;
    final generacion = _generacion;
    _deteccion = _analizar(
      frame,
      camara.description,
      detector,
      generacion,
    ).whenComplete(() => _deteccion = null);
  }

  Future<void> _analizar(
    CameraImage frame,
    CameraDescription camara,
    PoseDetector detector,
    int generacion,
  ) async {
    try {
      // camera_android entrega NV21 de un plano. No concatenar planos YUV420.
      if (frame.format.group != ImageFormatGroup.nv21 ||
          frame.planes.length != 1) {
        throw StateError('Formato de cámara no compatible con NV21');
      }
      final rotacion = InputImageRotationValue.fromRawValue(
        camara.sensorOrientation,
      );
      if (rotacion == null) {
        throw StateError('Orientacion de cámara no compatible');
      }
      final tamano = Size(frame.width.toDouble(), frame.height.toDouble());
      final input = InputImage.fromBytes(
        bytes: frame.planes.first.bytes,
        metadata: InputImageMetadata(
          size: tamano,
          rotation: rotacion,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.planes.first.bytesPerRow,
        ),
      );
      final poses = await detector.processImage(input);
      if (!_visible || !_activo || generacion != _generacion) return;
      _errores = 0;
      final pose = poses.isEmpty ? null : poses.first;
      final izq = pose?.landmarks[PoseLandmarkType.leftShoulder];
      final der = pose?.landmarks[PoseLandmarkType.rightShoulder];
      final torso =
          izq != null &&
          der != null &&
          izq.likelihood >= 0.65 &&
          der.likelihood >= 0.65;
      final nuevos = <PoseLandmarkType, Offset>{};
      if (pose != null) {
        for (final entry in pose.landmarks.entries) {
          if (entry.value.likelihood < 0.5) continue;
          final p = puntoEnVisor(
            Offset(entry.value.x, entry.value.y),
            tamano,
            camara.sensorOrientation,
            camara.lensDirection == CameraLensDirection.front,
          );
          // Sin coordenadas extrapoladas fuera del cuadro para los anclajes.
          if (!p.dx.isFinite ||
              !p.dy.isFinite ||
              p.dx < 0 ||
              p.dx > 1 ||
              p.dy < 0 ||
              p.dy > 1) {
            continue;
          }
          final anterior = _torso && torso ? _puntos[entry.key] : null;
          nuevos[entry.key] = anterior == null
              ? p
              : Offset.lerp(anterior, p, 0.4)!;
        }
      }
      _ultimaPose = DateTime.now();
      setState(() {
        _puntos = nuevos;
        _torso =
            torso &&
            nuevos.containsKey(PoseLandmarkType.leftShoulder) &&
            nuevos.containsKey(PoseLandmarkType.rightShoulder);
      });
    } catch (_) {
      if (!_visible || generacion != _generacion) return;
      _errores++;
      setState(() {
        _puntos = {};
        _torso = false;
        if (_errores >= 3) {
          _errorCamara =
              'No se pudo analizar la cámara. Reintenta o vuelve a Galería.';
        }
      });
    }
  }

  Future<void> _cargarPrenda(PrendaAr prenda) async {
    if (_imagenes.containsKey(prenda.clave) || !_cargando.add(prenda.clave)) {
      return;
    }
    if (_visible) setState(() => _errorPrenda = null);
    try {
      final Uint8List bytes;
      if (prenda.asset != null) {
        final data = await rootBundle.load(prenda.asset!);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } else {
        final response = await http
            .get(Uri.parse(prenda.url!))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw StateError('Imagen no disponible');
        }
        bytes = response.bodyBytes;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final ui.Image imagen;
      try {
        imagen = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!_visible) {
        imagen.dispose();
        return;
      }
      setState(() => _imagenes[prenda.clave] = imagen);
    } catch (_) {
      if (_visible && _prenda.clave == prenda.clave) {
        setState(
          () =>
              _errorPrenda = 'No se pudo cargar la prenda. Revisa tu conexión.',
        );
      }
    } finally {
      _cargando.remove(prenda.clave);
      if (_visible) setState(() {});
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _generacion++;
    WidgetsBinding.instance.removeObserver(this);
    _vigilarPose?.cancel();
    _operaciones = _operaciones
        .then((_) => _pararCamara())
        .catchError((Object _) {});
    for (final imagen in _imagenes.values) {
      imagen.dispose();
    }
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vestidor en vivo'),
        actions: [
          if (_camaras.length > 1)
            IconButton(
              tooltip: 'Cambiar cámara',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _iniciando
                  ? null
                  : () {
                      setState(() {
                        _indice = (_indice + 1) % _camaras.length;
                        _iniciando = true;
                      });
                      _programarCamara();
                    },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: _iniciando
                      ? const CircularProgressIndicator()
                      : camara == null
                      ? const Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                          size: 56,
                        )
                      : CameraPreview(
                          camara,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PrendaEnVivoPainter(
                                puntos: _puntos,
                                torso: _torso,
                                mostrarPuntos: _verPuntos,
                                prenda: _prenda,
                                imagen: _imagenes[_prenda.clave],
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_errorCamara != null) ...[
                        Text(
                          _errorCamara!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _programarCamara,
                          child: const Text('Reintentar cámara'),
                        ),
                      ] else
                        Text(
                          _torso
                              ? 'Sigue moviéndote: la prenda acompaña tus hombros.'
                              : 'Colócate de frente y aléjate hasta que se vean ambos hombros y el torso.',
                        ),
                      if (_cargando.contains(_prenda.clave))
                        const LinearProgressIndicator(),
                      if (_errorPrenda != null)
                        Row(
                          children: [
                            Expanded(child: Text(_errorPrenda!)),
                            TextButton(
                              onPressed: () => _cargarPrenda(_prenda),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in widget.prendas)
                            ChoiceChip(
                              label: Text(p.nombre),
                              avatar: CircleAvatar(backgroundColor: p.color),
                              selected: identical(p, _prenda),
                              onSelected: (_) {
                                setState(() {
                                  _prenda = p;
                                  _errorPrenda = null;
                                });
                                _cargarPrenda(p);
                              },
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar puntos detectados'),
                        value: _verPuntos,
                        onChanged: (v) => setState(() => _verPuntos = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrendaEnVivoPainter extends CustomPainter {
  _PrendaEnVivoPainter({
    required this.puntos,
    required this.torso,
    required this.mostrarPuntos,
    required this.prenda,
    required this.imagen,
  });
  final Map<PoseLandmarkType, Offset> puntos;
  final bool torso;
  final bool mostrarPuntos;
  final PrendaAr prenda;
  final ui.Image? imagen;

  @override
  void paint(Canvas canvas, Size size) {
    Offset pixel(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final a = puntos[PoseLandmarkType.leftShoulder];
    final b = puntos[PoseLandmarkType.rightShoulder];
    final img = imagen;
    if (torso && a != null && b != null && img != null) {
      final matriz = matrizPrenda(
        hombroA: pixel(a),
        hombroB: pixel(b),
        anclaIzq: prenda.hombroIzq,
        anclaDer: prenda.hombroDer,
        imagen: Size(img.width.toDouble(), img.height.toDouble()),
      );
      if (matriz != null) {
        canvas.save();
        canvas.transform(matriz.storage);
        canvas.drawImage(
          img,
          Offset.zero,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
      }
    }
    if (!mostrarPuntos) return;
    final blanco = Paint()..color = Colors.white;
    for (final p in puntos.values) {
      canvas.drawCircle(pixel(p), 3, blanco);
    }
    final esquinas = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftHip,
    ].map((t) => puntos[t]).toList();
    if (esquinas.every((p) => p != null)) {
      canvas.drawPath(
        Path()..addPolygon(esquinas.map((p) => pixel(p!)).toList(), true),
        Paint()
          ..color = Colors.greenAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final rojo = Paint()..color = Colors.redAccent;
    if (a != null) canvas.drawCircle(pixel(a), 7, rojo);
    if (b != null) canvas.drawCircle(pixel(b), 7, rojo);
  }

  @override
  bool shouldRepaint(covariant _PrendaEnVivoPainter oldDelegate) => true;
}
