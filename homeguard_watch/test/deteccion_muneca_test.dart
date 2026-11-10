import 'dart:math';
 
import 'package:flutter_test/flutter_test.dart';
import 'package:homeguard_watch/deteccion_muneca.dart';
 
/// Alimenta el detector con magnitudes (m/s²) a 50 Hz, todas en el eje Z.
bool detecta(List<double> magnitudes) {
  final d = DetectorCaidaMuneca();
  var resultado = false;
  for (var i = 0; i < magnitudes.length; i++) {
    if (d.procesar(i * 20, 0, 0, magnitudes[i])) resultado = true;
  }
  return resultado;
}
 
void main() {
  const g = 9.81;
  final rnd = Random(3);
  double ruido(double s) => (rnd.nextDouble() - 0.5) * 2 * s;
 
  test('detecta una caída: descenso, golpe y quietud', () {
    final List<double> senal = [
      for (var i = 0; i < 100; i++) g + ruido(0.3),
      for (var i = 0; i < 20; i++) 3 + ruido(0.5),
      35, 28, 15,
      for (var i = 0; i < 200; i++) g + ruido(0.3),
    ];
    expect(detecta(senal), isTrue);
  });
 
  test('detecta un golpe muy fuerte seguido de quietud (sin descenso visible)', () {
    final List<double> senal = [for (var i = 0; i < 100; i++) g, 42, 30, for (var i = 0; i < 200; i++) g + ruido(0.2)];
    expect(detecta(senal), isTrue);
  });
 
  test('no alarma al caminar', () {
    final List<double> senal = [for (var i = 0; i < 400; i++) g + 4 * sin(i * 2 * pi * 1.8 / 50) + ruido(0.5)];
    expect(detecta(senal), isFalse);
  });
 
  test('no alarma al golpear la mesa y seguir moviéndose', () {
    final List<double> senal = [for (var i = 0; i < 100; i++) g, 45, 20, for (var i = 0; i < 200; i++) g + 3 * sin(i / 3) + ruido(1)];
    expect(detecta(senal), isFalse);
  });
 
  test('no alarma al saltar y seguir caminando', () {
    final List<double> senal = [
      for (var i = 0; i < 100; i++) g,
      for (var i = 0; i < 15; i++) 2,
      30, 25,
      for (var i = 0; i < 200; i++) g + 5 * sin(i / 4) + ruido(1),
    ];
    expect(detecta(senal), isFalse);
  });
}
 
