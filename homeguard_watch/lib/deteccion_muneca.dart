import 'dart:collection';
import 'dart:math';

/// Detector de caídas para el reloj (sensor en la MUÑECA).
///
/// La muñeca se mueve mucho más que la cadera o el bolsillo (aplaudir, gesticular, golpear
/// una mesa), así que no se usa la red del teléfono. Se aplica la secuencia física de una
/// caída, la misma que usan los relojes comerciales:
///
///   1. Descenso: la aceleración baja de ~0,6 g (caída libre parcial) al menos 100 ms,
///      o hay un golpe muy fuerte (> 4 g) aunque no se haya visto el descenso.
///   2. Golpe: más de 2,5 g dentro de 1 s después del descenso.
///   3. Quietud: durante los 2,5 s siguientes la muñeca casi no se mueve.
///
/// Si se cumple, NO se envía la alerta de inmediato: el reloj muestra una cuenta
/// regresiva de 30 s para que la persona pueda decir «Estoy bien».
class DetectorCaidaMuneca {
  static const double g = 9.81;
  static const double umbralDescenso = 0.6 * g;
  static const int msDescensoMinimo = 100;
  static const double umbralGolpe = 2.5 * g;
  static const double umbralGolpeDirecto = 4.0 * g;
  static const int msMaxDescensoAGolpe = 1000;
  static const int msQuietud = 2500;
  static const double maxDesviacionQuieto = 1.2; // m/s²

  _Fase _fase = _Fase.buscando;
  int? _inicioDescensoMs;
  int? _finDescensoMs;
  int? _golpeMs;
  final Queue<_Lectura> _posteriores = Queue<_Lectura>();

  /// Procesa una lectura del acelerómetro (m/s²). Devuelve `true` cuando hay una
  /// posible caída que debe confirmarse con la persona.
  bool procesar(int tMs, double x, double y, double z) {
    final m = sqrt(x * x + y * y + z * z);

    switch (_fase) {
      case _Fase.buscando:
        if (m > umbralGolpeDirecto) {
          _empezarObservacion(tMs);
        } else if (m < umbralDescenso) {
          _inicioDescensoMs ??= tMs;
          if (tMs - _inicioDescensoMs! >= msDescensoMinimo) {
            _fase = _Fase.descenso;
          }
        } else {
          _inicioDescensoMs = null;
        }
        return false;

      case _Fase.descenso:
        if (m < umbralDescenso) {
          _finDescensoMs = tMs;
          return false;
        }
        _finDescensoMs ??= tMs;
        if (m > umbralGolpe) {
          _empezarObservacion(tMs);
        } else if (tMs - _finDescensoMs! > msMaxDescensoAGolpe) {
          reiniciar();
        }
        return false;

      case _Fase.observando:
        // Los primeros 300 ms después del golpe son rebotes: no cuentan para la quietud.
        if (tMs - _golpeMs! > 300) _posteriores.add(_Lectura(tMs, m));
        if (tMs - _golpeMs! < 300 + msQuietud) return false;
        final quieto = _estaQuieto();
        reiniciar();
        return quieto;
    }
  }

  void _empezarObservacion(int tMs) {
    _fase = _Fase.observando;
    _golpeMs = tMs;
    _posteriores.clear();
  }

  bool _estaQuieto() {
    if (_posteriores.length < 10) return false;
    final valores = _posteriores.map((l) => l.magnitud).toList();
    final media = valores.reduce((a, b) => a + b) / valores.length;
    var suma = 0.0;
    for (final v in valores) {
      suma += (v - media) * (v - media);
    }
    final desviacion = sqrt(suma / valores.length);
    // Quieto = poca variación y solo la gravedad (sin estar caminando ni agitando el brazo).
    return desviacion < maxDesviacionQuieto && media > 0.8 * g && media < 1.2 * g;
  }

  void reiniciar() {
    _fase = _Fase.buscando;
    _inicioDescensoMs = null;
    _finDescensoMs = null;
    _golpeMs = null;
    _posteriores.clear();
  }
}

enum _Fase { buscando, descenso, observando }

class _Lectura {
  final int tMs;
  final double magnitud;
  _Lectura(this.tMs, this.magnitud);
}
