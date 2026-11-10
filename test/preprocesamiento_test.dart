import 'package:flutter_test/flutter_test.dart';
import 'package:homeguard/services/ia/preprocesamiento.dart';

void main() {
  group('remuestrearAcelerometro', () {
    test('siempre entrega 250 muestras de 3 ejes', () {
      final r = remuestrearAcelerometro([const Muestra3D(0, 0, 0, 9.8)], 0);
      expect(r.length, VentanaRed.muestras);
      expect(r.every((f) => f.length == 3), isTrue);
    });

    test('interpola linealmente lecturas irregulares a 50 Hz', () {
      // Rampa en X: x = t/1000 (en segundos), con lecturas cada 70 ms (~15 Hz).
      final lecturas = [for (var t = -4000; t <= 2000; t += 70) Muestra3D(t, t / 1000, 0, 9.8)];
      final r = remuestrearAcelerometro(lecturas, 0);
      // Muestra 175 = instante del impacto (t = 0); muestra 0 = t = -3500 ms.
      expect(r[175][0], closeTo(0.0, 1e-9));
      expect(r[0][0], closeTo(-3.5, 1e-9));
      expect(r[100][0], closeTo(-1.5, 1e-9));
    });

    test('el pico del golpe queda en la posición 175', () {
      final lecturas = [
        for (var t = -4000; t <= 2000; t += 20) Muestra3D(t, 0, 0, t == 0 ? 40.0 : 9.8),
      ];
      final r = remuestrearAcelerometro(lecturas, 0);
      expect(r[175][2], 40.0);
      expect(r[174][2], 9.8);
    });

    test('sin lecturas devuelve gravedad en reposo', () {
      final r = remuestrearAcelerometro([], 1000);
      expect(r.first, [0.0, 0.0, 9.8]);
    });
  });

  group('espectrogramaCentrado', () {
    test('toma los cuadros alrededor del golpe, no los más antiguos', () {
      // 400 cuadros de 16 ms; cada cuadro guarda su número de orden en la banda 0.
      final cuadros = [
        for (var i = 0; i < 400; i++) CuadroAudio(i * 16, 50, List.filled(128, i.toDouble())),
      ];
      final impacto = 300 * 16;
      final e = espectrogramaCentrado(cuadros, impacto);
      expect(e.length, 128); // bandas
      expect(e[0].length, 128); // cuadros
      // El cuadro del impacto (300) cae en la mitad de la ventana.
      expect(e[0][64][0], 300.0);
      expect(e[0][0][0], 236.0);
    });

    test('rellena con ruido de fondo si hay pocos cuadros', () {
      final e = espectrogramaCentrado([const CuadroAudio(0, 60, null)], 0);
      expect(e[5][0][0], 60.0); // sin bandas usa el volumen global
      expect(e[5][127][0], VentanaRed.ruidoBaseDb);
    });
  });
}
