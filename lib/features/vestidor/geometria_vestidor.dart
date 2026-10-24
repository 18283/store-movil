import 'dart:math' as math;
import 'package:flutter/material.dart';

/// CU20: coordenadas Android de ML Kit sobre el preview vertical, sin recorte.
/// La rotacion describe el sensor; el espejo coincide con CameraPreview.
Offset puntoEnVisor(Offset punto, Size imagen, int rotacion, bool frontal) {
  final intercambia = rotacion == 90 || rotacion == 270;
  final ancho = intercambia ? imagen.height : imagen.width;
  final alto = intercambia ? imagen.width : imagen.height;
  final espejo = rotacion == 270 || (!intercambia && frontal);
  final x = punto.dx / ancho;
  return Offset(espejo ? 1 - x : x, punto.dy / alto);
}

/// Lleva los dos anclajes de la imagen a los hombros (coordenadas del visor).
Matrix4? matrizPrenda({
  required Offset hombroA,
  required Offset hombroB,
  required Offset anclaIzq,
  required Offset anclaDer,
  required Size imagen,
}) {
  var a = hombroA;
  var b = hombroB;
  if (a.dx > b.dx) {
    final tmp = a;
    a = b;
    b = tmp;
  }
  final izq = Offset(anclaIzq.dx * imagen.width, anclaIzq.dy * imagen.height);
  final der = Offset(anclaDer.dx * imagen.width, anclaDer.dy * imagen.height);
  final origen = der - izq;
  final destino = b - a;
  if (origen.distance < 0.001 ||
      destino.distance < 1 ||
      !origen.distance.isFinite ||
      !destino.distance.isFinite) {
    return null;
  }
  final centro = (a + b) / 2;
  final centroImagen = (izq + der) / 2;
  final escala = destino.distance / origen.distance;
  // En video suavizamos los puntos, sin el salto de la zona muerta de la foto.
  final giro =
      math.atan2(destino.dy, destino.dx) - math.atan2(origen.dy, origen.dx);
  return Matrix4.translationValues(centro.dx, centro.dy, 0) *
      Matrix4.rotationZ(giro) *
      Matrix4.diagonal3Values(escala, escala, 1) *
      Matrix4.translationValues(-centroImagen.dx, -centroImagen.dy, 0);
}
