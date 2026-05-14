import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alert_service.dart';
import 'local_ia_service.dart';
import 'sound_service.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final AlertService _alertService = AlertService();
  final LocalAIService _localAI = LocalAIService();

  bool _isMonitoring = false;
  DateTime? _lastFallTime;
  DateTime? _lastMovementTime;

  // Variables para el Dashboard de Actividad
  double _totalMagnitude = 0;
  int _magnitudeSamples = 0;
  double _totalDb = 0;
  int _dbSamples = 0;
  Timer? _activityTimer;

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    debugPrint("SENSOR MOVIMIENTO: Intentando conectar con el acelerómetro...");
    debugPrint("SENSOR MOVIMIENTO: Solicitando acceso a accelerometerEvents...");
    _accelerometerSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((AccelerometerEvent event) {
      _analyzeMovement(event);
    }, onError: (e) {
      debugPrint("ERROR CRÍTICO EN ACELERÓMETRO: $e");
    });

    // Iniciar monitoreo de sonido
    SoundService().startMonitoring();

    // Iniciar registro de actividad para el dashboard
    _startActivityLogging();
  }

  void _startActivityLogging() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendActivitySnapshot();
    });
  }

  Future<void> _sendActivitySnapshot() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _magnitudeSamples == 0) return;

    double avgMagnitude = _totalMagnitude / _magnitudeSamples;
    double avgDb = _dbSamples > 0 ? (_totalDb / _dbSamples) : 0.0;

    // Reiniciar contadores para el siguiente periodo
    _totalMagnitude = 0;
    _magnitudeSamples = 0;
    _totalDb = 0;
    _dbSamples = 0;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity_logs')
          .add({
        'movementIndex': avgMagnitude,
        'noiseIndex': avgDb,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint("IA DASHBOARD: Snapshot enviado. G=${avgMagnitude.toStringAsFixed(2)}, dB=${avgDb.toStringAsFixed(1)}");
    } catch (e) {
      debugPrint("IA DASHBOARD ERROR: $e");
    }
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _activityTimer?.cancel();
    SoundService().stopMonitoring();
    _isMonitoring = false;
  }

  void _analyzeMovement(AccelerometerEvent event) {
    // Acumular datos para el dashboard (Promedio de movimiento)
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _totalMagnitude += magnitude;
    _magnitudeSamples++;

    // 1. Detectar patrón de caída (IA de varios estados)
    if (_localAI.detectFall(event.x, event.y, event.z)) {
      // Evitar alertas duplicadas en poco tiempo (15 segundos)
      if (_lastFallTime == null || 
          DateTime.now().difference(_lastFallTime!) > const Duration(seconds: 15)) {
        
        _lastFallTime = DateTime.now();
        _handleFallDetected();
      }
    }

    // 2. Detectar agitación violenta (Alerta de Movimiento)
    if (_localAI.detectShaking(event.x, event.y, event.z)) {
      // Cooldown de 10 segundos para alertas de movimiento
      if (_lastMovementTime == null || 
          DateTime.now().difference(_lastMovementTime!) > const Duration(seconds: 10)) {
        
        _lastMovementTime = DateTime.now();
        _handleMovementDetected();
      }
    }
  }

  /// Maneja las actualizaciones de audio enviadas por el SoundService
  void handleAudioUpdate(double db) {
    // Acumular datos para el dashboard (Nivel de ruido ambiental)
    if (db > 0) {
      _totalDb += db;
      _dbSamples++;
    }

    if (_localAI.updateAudioLevel(db)) {
      _handleEmergencySound();
    }
  }

  Future<void> _handleEmergencySound() async {
    debugPrint("¡GRITO O IMPACTO SONORO DETECTADO!");
    
    await _alertService.enviarAlerta(
      tipo: 'sonido_emergencia',
      mensaje: 'ALERTA: Se ha detectado un sonido fuerte (posible grito o accidente) cerca del paciente.',
    );
  }

  Future<void> _handleFallDetected() async {
    debugPrint("¡CAÍDA CONFIRMADA POR IA LOCAL!");
    
    await _alertService.enviarAlerta(
      tipo: 'caida',
      mensaje: '¡ALERTA! La IA local ha detectado una caída. Por favor verifica el estado del paciente.',
    );
  }

  Future<void> _handleMovementDetected() async {
    debugPrint("¡MOVIMIENTO AGRESIVO DETECTADO!");
    
    await _alertService.enviarAlerta(
      tipo: 'movimiento',
      mensaje: 'Se ha detectado un movimiento brusco o agitación en el dispositivo del paciente.',
    );
  }
}
