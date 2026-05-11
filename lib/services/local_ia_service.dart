import 'dart:math';
import 'package:flutter/foundation.dart';

/// Servicio de Inteligencia Artificial Local (On-device AI)
/// No requiere conexión a internet para funcionar.
class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  // Buffer para almacenar muestras recientes (Ventana de tiempo)
  final List<double> _magnitudeBuffer = [];
  static const int _bufferLimit = 50; // Aprox 1-2 segundos de datos

  /// Analiza si un evento de sensores corresponde a una caída real.
  /// Implementa un algoritmo de reconocimiento de patrones basado en heurísticas de IA.
  bool detectFall(double x, double y, double z) {
    double magnitude = sqrt(x * x + y * y + z * z);
    
    // Añadir al buffer
    _magnitudeBuffer.add(magnitude);
    if (_magnitudeBuffer.length > _bufferLimit) {
      _magnitudeBuffer.removeAt(0);
    }

    if (_magnitudeBuffer.length < 20) return false;

    // Patrón de caída típico:
    // 1. Caída libre (magnitud < 3 m/s2)
    // 2. Seguido de Impacto (magnitud > 25 m/s2)
    // 3. Seguido de Inactividad (varianza baja)

    bool freeFallFound = false;
    bool impactFound = false;
    int impactIndex = -1;

    for (int i = 0; i < _magnitudeBuffer.length; i++) {
      if (_magnitudeBuffer[i] < 3.0) {
        freeFallFound = true;
      }
      if (freeFallFound && _magnitudeBuffer[i] > 25.0) {
        impactFound = true;
        impactIndex = i;
        break;
      }
    }

    if (impactFound && impactIndex != -1 && impactIndex < _magnitudeBuffer.length - 10) {
      // Verificar "Inactividad" tras el impacto (para no confundir con correr o saltar)
      double variance = _calculateVariance(_magnitudeBuffer.sublist(impactIndex));
      if (variance < 10.0) {
        debugPrint("IA LOCAL: ¡CAÍDA CONFIRMADA POR PATRÓN!");
        return true;
      }
    }

    return false;
  }

  /// Verifica si el paciente está en una "Zona Segura" localmente
  /// No requiere internet.
  bool isInsideSafeZoneLocal(double currentLat, double currentLon, double safeLat, double safeLon, double radius) {
    double distance = _haversineDistance(currentLat, currentLon, safeLat, safeLon);
    return distance <= radius;
  }

  double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0;
    double mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiff = data.map((x) => pow(x - mean, 2)).fold(0.0, (a, b) => a + b);
    return sumSquaredDiff / data.length;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
