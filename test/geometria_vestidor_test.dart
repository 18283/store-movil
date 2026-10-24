import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_movil/features/vestidor/geometria_vestidor.dart';

void main() {
  test('Sensor 90: orienta un frame horizontal al visor vertical', () {
    expect(
      puntoEnVisor(const Offset(120, 160), const Size(640, 480), 90, false),
      const Offset(0.25, 0.25),
    );
  });
  test('Sensor frontal 270: refleja X sin invertir altura', () {
    expect(
      puntoEnVisor(const Offset(120, 160), const Size(640, 480), 270, true),
      const Offset(0.75, 0.25),
    );
  });
  test('Sensor sin giro: solo la camara frontal aplica espejo', () {
    expect(
      puntoEnVisor(const Offset(160, 120), const Size(640, 480), 0, false),
      const Offset(0.25, 0.25),
    );
    expect(
      puntoEnVisor(const Offset(160, 120), const Size(640, 480), 0, true),
      const Offset(0.75, 0.25),
    );
  });
  for (final destino in <List<Offset>>[
    [const Offset(100, 120), const Offset(300, 120)],
    [const Offset(120, 100), const Offset(380, 190)],
    [const Offset(220, 180), const Offset(100, 130)],
  ]) {
    test(
      'Las anclas coinciden con hombros ante traslacion, escala y giro: $destino',
      () {
        final matriz = matrizPrenda(
          hombroA: destino[0],
          hombroB: destino[1],
          anclaIzq: const Offset(0.27, 0.15625),
          anclaDer: const Offset(0.73, 0.15625),
          imagen: const Size(1000, 960),
        )!;
        final orden = [...destino]..sort((a, b) => a.dx.compareTo(b.dx));
        final a = MatrixUtils.transformPoint(matriz, const Offset(270, 150));
        final b = MatrixUtils.transformPoint(matriz, const Offset(730, 150));
        expect((a - orden[0]).distance, lessThan(0.00001));
        expect((b - orden[1]).distance, lessThan(0.00001));
      },
    );
  }
  test('Anclas coincidentes no producen escala infinita', () {
    expect(
      matrizPrenda(
        hombroA: const Offset(10, 20),
        hombroB: const Offset(30, 20),
        anclaIzq: Offset.zero,
        anclaDer: Offset.zero,
        imagen: const Size(1000, 960),
      ),
      isNull,
    );
  });
}
