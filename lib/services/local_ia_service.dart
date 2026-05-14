import 'dart:math';
import 'package:flutter/foundation.dart';

enum FallState { searching, freeFallDetected, impactDetected, confirmed }

class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  // Estados de la IA
  FallState _currentState = FallState.searching;
  DateTime? _stateStartTime;
  
  // Memoria de sonido reciente
  bool _loudNoiseDetectedRecently = false;
  DateTime? _lastLoudNoiseTime;
  DateTime? _lastEmergencySoundTime;

  // Umbrales calibrados para robustez avanzada (Enfocado en Personas Mayores)
  static const double _freeFallThreshold = 5.0;    // Más sensible para caídas lentas
  static const double _impactThreshold = 16.0;    // Reducido para captar caídas menos violentas
  static const double _moderateImpactThreshold = 14.0; // Umbral para fusión con sonido
  static const double _criticalImpactThreshold = 22.0; // Bajado para asegurar alertas en golpes secos
  static const double _quietThresholdLow = 7.5;    
  static const double _quietThresholdHigh = 12.5;  
  static const double _loudNoiseThreshold = 70.0; // Ignora ruido ambiental y conversaciones normales
  static const double _emergencySoundThreshold = 85.0; // Solo captura gritos fuertes o impactos secos
  static const double _shakeThreshold = 40.0; // Requiere una agitación más deliberada para evitar falsas alarmas

  // Tiempos
  static const int _maxFreeFallToImpactMs = 1200; // Más tiempo para caídas complejas
  static const int _minQuietDurationMs = 2000;     // 2 segundos de quietud para confirmar (más seguro)

  /// Actualiza el nivel de sonido y verifica si es una emergencia (grito/accidente)
  bool updateAudioLevel(double db) {
    bool isEmergency = false;

    if (db > _loudNoiseThreshold) {
      _loudNoiseDetectedRecently = true;
      _lastLoudNoiseTime = DateTime.now();
      
      // Si es extremadamente fuerte (Grito), activamos alerta inmediata
      if (db > _emergencySoundThreshold) {
        // Cooldown de 10 segundos para no saturar con el mismo grito
        if (_lastEmergencySoundTime == null || 
            DateTime.now().difference(_lastEmergencySoundTime!).inSeconds > 10) {
          isEmergency = true;
          _lastEmergencySoundTime = DateTime.now();
          debugPrint("IA MULTIMODAL: ¡SONIDO DE EMERGENCIA DETECTADO! (dB: ${db.toStringAsFixed(1)})");
        }
      }
    }
    
    // Limpiar ruidos viejos tras 2 segundos para la fusión con caídas
    if (_lastLoudNoiseTime != null && 
        DateTime.now().difference(_lastLoudNoiseTime!).inSeconds > 2) {
      _loudNoiseDetectedRecently = false;
    }

    return isEmergency;
  }

  /// Analiza el movimiento usando Fusión de Sensores (Movimiento + Sonido)
  bool detectFall(double x, double y, double z) {
    double magnitude = sqrt(x * x + y * y + z * z);
    DateTime now = DateTime.now();

    // 1. Detección de impacto crítico directo (sin caída libre previa)
    if (magnitude > _criticalImpactThreshold && _currentState == FallState.searching) {
      _currentState = FallState.impactDetected;
      _stateStartTime = now;
      debugPrint("IA AVANZADA: ¡IMPACTO CRÍTICO DIRECTO! (G=${magnitude.toStringAsFixed(1)})");
    }

    // 2. FUSIÓN DE SENSORES: Impacto moderado + Sonido reciente
    // Si hubo un ruido fuerte (golpe) y un movimiento brusco, es muy probable que sea una caída
    if (magnitude > _moderateImpactThreshold && _loudNoiseDetectedRecently && _currentState == FallState.searching) {
      _currentState = FallState.impactDetected;
      _stateStartTime = now;
      debugPrint("IA AVANZADA: ¡FUSIÓN IMPACTO+SONIDO! (G=${magnitude.toStringAsFixed(1)})");
    }

    switch (_currentState) {
      case FallState.searching:
        if (magnitude < _freeFallThreshold) {
          _currentState = FallState.freeFallDetected;
          _stateStartTime = now;
          debugPrint("IA AVANZADA: Fase 1 - Caída iniciada (G=${magnitude.toStringAsFixed(1)})");
        }
        break;

      case FallState.freeFallDetected:
        if (now.difference(_stateStartTime!).inMilliseconds > _maxFreeFallToImpactMs) {
          debugPrint("IA MULTIMODAL: Timeout en caída libre (G=${magnitude.toStringAsFixed(1)}), volviendo a buscar...");
          _currentState = FallState.searching;
          return false;
        }
        if (magnitude > _impactThreshold) {
          _currentState = FallState.impactDetected;
          _stateStartTime = now;
          debugPrint("IA MULTIMODAL: Fase 2 - ¡GOLPE DETECTADO! (G=${magnitude.toStringAsFixed(1)})");
        }
        break;

      case FallState.impactDetected:
        bool isQuiet = magnitude > _quietThresholdLow && magnitude < _quietThresholdHigh;
        
        if (!isQuiet) {
          // Si hay otro golpe muy fuerte o cae de nuevo, reiniciamos el contador de quietud
          if (magnitude > _impactThreshold || magnitude < _freeFallThreshold) {
             debugPrint("IA MULTIMODAL: Movimiento detectado post-impacto, reiniciando fase de quietud.");
             _stateStartTime = now; 
          }
          
          // Si el movimiento es constante y NO es quietud por mucho tiempo, cancelar
          if (now.difference(_stateStartTime!).inSeconds > 4) {
            debugPrint("IA MULTIMODAL: Demasiado movimiento post-impacto, cancelando alerta de caída.");
            _currentState = FallState.searching;
          }
        } else {
          if (now.difference(_stateStartTime!).inMilliseconds > _minQuietDurationMs) {
            _currentState = FallState.searching;
            
            if (_loudNoiseDetectedRecently) {
              debugPrint("IA MULTIMODAL: ¡CAÍDA CONFIRMADA CON SONIDO! (G=${magnitude.toStringAsFixed(1)})");
            } else {
              debugPrint("IA MULTIMODAL: ¡CAÍDA CONFIRMADA POR MOVIMIENTO! (G=${magnitude.toStringAsFixed(1)})");
            }
            return true;
          }
        }
        break;

      default:
        _currentState = FallState.searching;
    }

    return false;
  }

  /// Detecta si el teléfono está siendo agitado violentamente
  bool detectShaking(double x, double y, double z) {
    double magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude > _shakeThreshold) {
      debugPrint("IA MULTIMODAL: ¡AGITACIÓN DETECTADA! (G=${magnitude.toStringAsFixed(1)})");
      return true;
    }
    return false;
  }

  /// Verifica si el paciente está en una "Zona Segura" localmente
  bool isInsideSafeZoneLocal(double currentLat, double currentLon, double safeLat, double safeLon, double radius) {
    double distance = _haversineDistance(currentLat, currentLon, safeLat, safeLon);
    return distance <= radius;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}
