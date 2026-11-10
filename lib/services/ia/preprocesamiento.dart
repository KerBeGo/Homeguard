/// Preparación de las entradas de la red neuronal de detección de caídas.
///
/// Funciones puras (sin Flutter ni Firebase) para poder probarlas con `flutter test`.
///
/// Por qué existe este archivo:
/// la red fue entrenada con ventanas de 5 s del acelerómetro a 50 Hz (250 muestras)
/// y 128 cuadros de espectrograma. La app le entregaba lecturas a ~15 Hz, rellenadas
/// repitiendo la última, y el audio de ANTES del golpe. Con esas entradas, la red
/// casi nunca reconocía una caída real.
library;

/// Una lectura con su instante en milisegundos.
class Muestra3D {
  final int tMs;
  final double x, y, z;
  const Muestra3D(this.tMs, this.x, this.y, this.z);
}

/// Parámetros de la ventana con que se entrenó la red.
class VentanaRed {
  static const int hz = 50;
  static const int muestras = 250; // 5 s a 50 Hz
  static const int msAntes = 3500; // 3,5 s antes del impacto
  static const int msDespues = 1500; // 1,5 s después
  static const int cuadrosAudio = 128;
  static const int bandasAudio = 128;
  static const double ruidoBaseDb = 45.0;

  /// Memoria mínima que debe guardar el búfer: la ventana completa más la
  /// observación posterior al impacto (la evaluación ocurre 2,5 s después del golpe).
  static const int memoriaMs = msAntes + 2500 + 1000;
}

/// Remuestrea lecturas irregulares a una rejilla exacta de [VentanaRed.hz] Hz entre
/// `impactoMs - msAntes` e `impactoMs + msDespues`, con interpolación lineal.
/// Fuera del rango disponible se repite el valor del extremo más cercano.
/// Devuelve [VentanaRed.muestras] filas de [x, y, z].
List<List<double>> remuestrearAcelerometro(List<Muestra3D> lecturas, int impactoMs) {
  if (lecturas.isEmpty) {
    return List.generate(VentanaRed.muestras, (_) => [0.0, 0.0, 9.8]);
  }
  final ordenadas = [...lecturas]..sort((a, b) => a.tMs.compareTo(b.tMs));
  final inicio = impactoMs - VentanaRed.msAntes;
  const pasoMs = 1000 / VentanaRed.hz;

  final salida = <List<double>>[];
  var j = 0;
  for (var i = 0; i < VentanaRed.muestras; i++) {
    final t = inicio + i * pasoMs;
    while (j < ordenadas.length - 1 && ordenadas[j + 1].tMs <= t) {
      j++;
    }
    final a = ordenadas[j];
    if (t <= ordenadas.first.tMs) {
      final p = ordenadas.first;
      salida.add([p.x, p.y, p.z]);
    } else if (j == ordenadas.length - 1) {
      salida.add([a.x, a.y, a.z]);
    } else {
      final b = ordenadas[j + 1];
      final span = (b.tMs - a.tMs).toDouble();
      final f = span <= 0 ? 0.0 : (t - a.tMs) / span;
      salida.add([
        a.x + (b.x - a.x) * f,
        a.y + (b.y - a.y) * f,
        a.z + (b.z - a.z) * f,
      ]);
    }
  }
  return salida;
}

/// Un cuadro de audio: instante y las bandas de frecuencia en dB.
class CuadroAudio {
  final int tMs;
  final double db;
  final List<double>? bandas;
  const CuadroAudio(this.tMs, this.db, this.bandas);
}

/// Construye el espectrograma [bandas][cuadros][1] centrado en el impacto:
/// los [VentanaRed.cuadrosAudio] cuadros más cercanos al golpe (mitad antes,
/// mitad después). Antes se tomaban los más antiguos del búfer, todos previos al golpe.
List<List<List<double>>> espectrogramaCentrado(List<CuadroAudio> cuadros, int impactoMs) {
  const n = VentanaRed.cuadrosAudio;
  final ordenados = [...cuadros]..sort((a, b) => a.tMs.compareTo(b.tMs));

  var centro = 0;
  for (var i = 0; i < ordenados.length; i++) {
    if (ordenados[i].tMs <= impactoMs) centro = i;
  }
  var desde = centro - n ~/ 2;
  if (desde + n > ordenados.length) desde = ordenados.length - n;
  if (desde < 0) desde = 0;
  final seleccion = ordenados.skip(desde).take(n).toList();

  return List.generate(VentanaRed.bandasAudio, (f) {
    return List.generate(n, (t) {
      if (t >= seleccion.length) return [VentanaRed.ruidoBaseDb];
      final c = seleccion.elementAt(t);
      final bandas = c.bandas;
      return [bandas != null && bandas.length > f ? bandas[f] : c.db];
    });
  });
}
