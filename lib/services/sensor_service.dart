import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'alert_service.dart';
import 'package:flutter/foundation.dart';
import 'local_ia_service.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final AlertService _alertService = AlertService();
  final LocalAIService _localAI = LocalAIService();

  bool _isMonitoring = false;
  DateTime? _lastFallTime;

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      _analyzeMovement(event);
    });
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _isMonitoring = false;
  }

  void _analyzeMovement(AccelerometerEvent event) {
    // Usar la IA Local para detectar el patrón de caída
    if (_localAI.detectFall(event.x, event.y, event.z)) {
      // Evitar alertas duplicadas en poco tiempo (15 segundos)
      if (_lastFallTime == null || 
          DateTime.now().difference(_lastFallTime!) > const Duration(seconds: 15)) {
        
        _lastFallTime = DateTime.now();
        _handleFallDetected();
      }
    }
  }

  Future<void> _handleFallDetected() async {
    debugPrint("¡CAÍDA CONFIRMADA POR IA LOCAL!");
    
    await _alertService.enviarAlerta(
      tipo: 'caida',
      mensaje: '¡ALERTA! La IA local ha detectado una caída. Por favor verifica el estado del paciente.',
    );
  }
}
