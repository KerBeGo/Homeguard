import 'dart:math';
import 'dart:collection';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
  try {
    LocalAIService().addLog(message);
  } catch (e) {
    // Ignore if not initialized yet
  }
}

enum FallState { searching, freeFallDetected, impactDetected, confirmed }

class AccelerometerEntry {
  final DateTime time;
  final double x;
  final double y;
  final double z;
  final double magnitude;

  AccelerometerEntry({
    required this.time,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}

class AudioEntry {
  final DateTime time;
  final double db;
  final List<double>? frequencies;

  AudioEntry({
    required this.time,
    required this.db,
    this.frequencies,
  });
}

class LocalAIService {
  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal() {
    // Intentar inicializar el modelo de TensorFlow Lite al instanciar el servicio
    Future.microtask(() => initializeModel());
    Future.microtask(() => _loadCalibration());
  }

  int _falsePositivesCount = 0;
  bool _isTrainingMode = true; // Modo entrenamiento por defecto

  bool get isTrainingMode => _isTrainingMode;

  Future<void> _loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    _falsePositivesCount = prefs.getInt('falsePositivesCount') ?? 0;
    _isTrainingMode = prefs.getBool('isTrainingMode') ?? true;
  }

  Future<void> setTrainingMode(bool value) async {
    _isTrainingMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTrainingMode', value);
    debugPrint("IA EDGE INFO: Modo entrenamiento ${value ? 'ACTIVADO' : 'DESACTIVADO'}");
  }

  void _applyCalibrationOffset() {
    // Por cada falso positivo reportado, el sistema se hace un poco más "duro"
    // Máximo 15 niveles de endurecimiento (aprox 30% más duro).
    int offsetLevel = _falsePositivesCount;
    if (offsetLevel > 15) offsetLevel = 15;
    
    double multiplier = 1.0 + (offsetLevel * 0.02); // +2% por cada falso positivo
    
    _moderateImpactThreshold *= multiplier;
    _impactThreshold *= multiplier;
    _criticalImpactThreshold *= multiplier;
    _shakeThreshold *= multiplier;
    
    debugPrint("IA EDGE INFO: Aprendizaje Activo Aplicado. Multiplicador de impacto: ${multiplier.toStringAsFixed(2)}x (Basado en $_falsePositivesCount correcciones).");
  }

  void reportFalsePositive(String tipo) async {
    _falsePositivesCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('falsePositivesCount', _falsePositivesCount);
    
    debugPrint("IA EDGE LEARNING: Falso positivo de tipo '$tipo' reportado por el usuario. Re-calibrando umbrales...");
    // Volver a aplicar los niveles base y luego el nuevo offset
    setSensitivityLevel(_sensitivityLevel);
  }

  // Stream de logs para el Dashboard del Desarrollador
  final StreamController<String> _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;
  final List<String> recentLogs = [];

  void addLog(String message) {
    final timeStr = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
    final formattedMessage = "[$timeStr] $message";
    
    recentLogs.insert(0, formattedMessage);
    if (recentLogs.length > 200) {
      recentLogs.removeLast();
    }
    _logController.add(formattedMessage);

    // Subir log remotamente a Firestore para que el cuidador pueda monitorear la IA
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('developer_logs').add({
        'message': formattedMessage,
        'timestamp': FieldValue.serverTimestamp(),
        'uid': user.uid,
      }).then((_) {}, onError: (e) {
        // Ignorar el error de subida silenciosamente para no detener el flujo local
      });
    }
  }

  // Intérprete y estado de TensorFlow Lite (Edge AI)
  tfl.Interpreter? _interpreter;
  bool _isModelLoaded = false;
  static const String _modelAssetPath = 'assets/modelo_fusion.tflite';

  // Estados de la IA
  FallState _currentState = FallState.searching;
  DateTime? _stateStartTime;
  DateTime? _impactPeakTime;
  double _maxImpactMagnitude = 0.0;

  // Buffers deslizantes (Ventana de 5 segundos para Fusión Intermedia)
  final Queue<AccelerometerEntry> _accBuffer = Queue<AccelerometerEntry>();
  final Queue<AudioEntry> _audioBuffer = Queue<AudioEntry>();

  static const int _windowDurationMs = 5000; // Ventana de 5 segundos de memoria
  static const int _postImpactObservationMs = 2500; // Tiempo para observar quietud y voz post-golpe

  // Memoria de sonido reciente para compatibilidad externa
  DateTime? _lastEmergencySoundTime;

  // Nivel de sensibilidad actual
  String _sensitivityLevel = "MEDIA";
  String get sensitivityLevel => _sensitivityLevel;

  // Umbrales dinámicos adaptativos (Por defecto: MEDIA)
  double _freeFallThreshold = 3.5;    // Umbral de baja gravedad (m/s²)
  double _moderateImpactThreshold = 20.0; // Umbral de disparo para iniciar fusión
  double _impactThreshold = 25.0;    // Umbral de impacto severo
  double _criticalImpactThreshold = 35.0; // Impacto crítico directo
  double _loudNoiseThreshold = 82.0; // Umbral de ruido fuerte candidato a grito
  double _emergencySoundThreshold = 88.0; // Umbral de gritos
  double _shakeThreshold = 75.0; // Umbral de agitación (m/s²)

  /// Ajusta los umbrales según el perfil del usuario (ALTA = Muy sensible, BAJA = Poco sensible)
  void setSensitivityLevel(String level) {
    _sensitivityLevel = level.toUpperCase();
    if (_sensitivityLevel == "ALTA") {
      // Para personas con movilidad muy reducida (caídas suaves/cortas)
      _freeFallThreshold = 4.0; 
      _moderateImpactThreshold = 14.0; // Muy sensible
      _impactThreshold = 18.0; 
      _criticalImpactThreshold = 25.0;
      _loudNoiseThreshold = 88.0; 
      _emergencySoundThreshold = 95.0; 
      _shakeThreshold = 25.0; // Muy fácil dar alerta de agitación
      debugPrint("IA EDGE INFO: Sensibilidad configurada a ALTA. Umbrales ajustados para mayor detección.");
    } else if (_sensitivityLevel == "BAJA") {
      // Para personas activas
      _freeFallThreshold = 2.5; 
      _moderateImpactThreshold = 25.0; 
      _impactThreshold = 30.0;
      _criticalImpactThreshold = 45.0;
      _loudNoiseThreshold = 95.0;
      _emergencySoundThreshold = 105.0;
      _shakeThreshold = 60.0; 
      debugPrint("IA EDGE INFO: Sensibilidad configurada a BAJA. Umbrales ajustados para evitar falsos positivos.");
    } else {
      // MEDIA (Balanceada, ajustada para pruebas en cama)
      _freeFallThreshold = 3.5;
      _moderateImpactThreshold = 18.0; // Reducido para detectar golpes en colchón
      _impactThreshold = 22.0;
      _criticalImpactThreshold = 30.0;
      _loudNoiseThreshold = 92.0;
      _emergencySoundThreshold = 100.0;
      _shakeThreshold = 35.0; // Reducido para detectar sacudidas manuales
      debugPrint("IA EDGE INFO: Sensibilidad configurada a MEDIA. Umbrales balanceados.");
    }
    
    _applyCalibrationOffset();
  }

  /// Carga e inicializa el modelo Edge AI (.tflite) desde los assets locales
  Future<void> initializeModel() async {
    try {
      debugPrint("IA EDGE: Intentando cargar modelo TFLite desde $_modelAssetPath...");
      _interpreter = await tfl.Interpreter.fromAsset(_modelAssetPath);
      _isModelLoaded = true;
      debugPrint("IA EDGE: ¡Modelo neuronal de Fusión Intermedia cargado correctamente!");
      
      // Depuración de las dimensiones esperadas de los tensores
      final inputTensors = _interpreter!.getInputTensors();
      for (int i = 0; i < inputTensors.length; i++) {
        debugPrint("IA EDGE: Input Tensor $i: Name=${inputTensors[i].name}, Shape=${inputTensors[i].shape}, Type=${inputTensors[i].type}");
      }
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < outputTensors.length; i++) {
        debugPrint("IA EDGE: Output Tensor $i: Name=${outputTensors[i].name}, Shape=${outputTensors[i].shape}, Type=${outputTensors[i].type}");
      }
    } catch (e) {
      _isModelLoaded = false;
      _interpreter = null;
      debugPrint("IA EDGE WARNING: No se pudo cargar el modelo TFLite ($e).");
      debugPrint("IA EDGE INFO: Se usará el Motor de Fusión Heurístico de respaldo (100% operativo).");
    }
  }


  /// Actualiza el nivel de sonido en el buffer y verifica emergencias acústicas directas
  bool updateAudioLevel(double db, List<double>? frequencies) {
    bool isEmergency = false;
    final now = DateTime.now();

    // Guardar en el buffer deslizante
    _audioBuffer.add(AudioEntry(time: now, db: db, frequencies: frequencies));
    _pruneBuffers(now);

    // Si es un sonido de intensidad candidata a grito (más de _loudNoiseThreshold)
    if (db > _loudNoiseThreshold) {
      // 1. Evaluar si es un sonido sostenido en el último 1.5s
      final windowStart = now.subtract(const Duration(milliseconds: 1500));
      List<AudioEntry> recentSamples = _audioBuffer.where((e) => e.time.isAfter(windowStart)).toList();
      
      double peakDb = db;
      for (var entry in recentSamples) {
        if (entry.db > peakDb) {
          peakDb = entry.db;
        }
      }

      // Si el pico de la ventana supera el umbral de gritos
      if (peakDb >= _emergencySoundThreshold) {
        // Contar cuántas muestras en el último 1.5s superan el umbral de ruido alto
        // Esto ayuda a comprobar que no sea solo un pico instantáneo o soplido
        int loudSamplesCount = recentSamples.where((e) => e.db > _loudNoiseThreshold).length;
        
        // Esperamos al menos 4 muestras para considerar que es un grito sostenido (aprox 400ms o más)
        double sustainedRatio = loudSamplesCount / 4.0;
        if (sustainedRatio > 1.0) sustainedRatio = 1.0;

        // Calcular puntaje de intensidad normalizado (entre _emergencySoundThreshold y 120 dB)
        double intensityScore = (peakDb - _emergencySoundThreshold) / (120.0 - _emergencySoundThreshold);
        intensityScore = intensityScore.clamp(0.0, 1.0);

        // Fusión acústica: 60% peso a la duración (sostenido) y 40% a la intensidad pico
        double screamProbability = (intensityScore * 0.4) + (sustainedRatio * 0.6);

        if (screamProbability >= 0.70) {
          // Verificar si este sonido coincide con un golpe del acelerómetro para no enviar una falsa alarma de grito
          bool isCoincidentWithImpact = false;
          final halfSecondAgo = now.subtract(const Duration(milliseconds: 500));
          for (var entry in _accBuffer) {
            if (entry.time.isAfter(halfSecondAgo) && entry.magnitude > _moderateImpactThreshold) {
              isCoincidentWithImpact = true;
              break;
            }
          }

          bool confirmScream = true;
          if (isCoincidentWithImpact) {
            // Si hubo un impacto, somos mucho más estrictos con la duración del sonido
            // Un impacto duro mecánico dura 1-2 muestras. Si dura más de 6 muestras, es muy probable que sea un grito real simultáneo.
            if (loudSamplesCount < 6) {
              confirmScream = false;
              debugPrint("IA MULTIMODAL: Sonido de emergencia con alta probabilidad (${(screamProbability * 100).toStringAsFixed(1)}%, dB: ${peakDb.toStringAsFixed(1)}) detectado, pero ignorado por coincidencia con impacto físico (falso grito causado por golpe). Muestras altas: $loudSamplesCount");
            } else {
              debugPrint("IA MULTIMODAL: Sonido de emergencia coincide con impacto, pero duración sostenida confirma grito real (Muestras altas: $loudSamplesCount).");
            }
          }

          if (confirmScream) {
            // Cooldown de 10 segundos para no saturar con el mismo grito
            if (_lastEmergencySoundTime == null || 
                now.difference(_lastEmergencySoundTime!).inSeconds > 10) {
              isEmergency = true;
              _lastEmergencySoundTime = now;
              debugPrint("IA MULTIMODAL: ¡SONIDO DE EMERGENCIA DETECTADO! (dB: ${peakDb.toStringAsFixed(1)}, Probabilidad: ${(screamProbability * 100).toStringAsFixed(1)}%)");
            }
          }
        } else {
          // Registrar el falso positivo de grito con su probabilidad en consola
          debugPrint("IA MULTIMODAL: Sonido de ${peakDb.toStringAsFixed(1)} dB ignorado por baja probabilidad de grito (${(screamProbability * 100).toStringAsFixed(1)}%). Falso positivo de grito.");
        }
      }
    }

    return isEmergency;
  }

  /// Registra el movimiento en el buffer y ejecuta la máquina de estados de Fusión Intermedia
  bool detectFall(double x, double y, double z) {
    final now = DateTime.now();
    double magnitude = sqrt(x * x + y * y + z * z);

    // Guardar en el buffer deslizante
    _accBuffer.add(AccelerometerEntry(time: now, x: x, y: y, z: z, magnitude: magnitude));
    _pruneBuffers(now);

    // 1. Detección de impacto crítico directo (sin caída libre previa)
    if (magnitude > _criticalImpactThreshold && _currentState == FallState.searching) {
      _currentState = FallState.impactDetected;
      _stateStartTime = now;
      _impactPeakTime = now;
      _maxImpactMagnitude = magnitude;
      debugPrint("IA AVANZADA: ¡IMPACTO CRÍTICO DIRECTO REGISTRADO! (G=${magnitude.toStringAsFixed(1)})");
    }

    // 2. FUSIÓN DE SENSORES: Impacto moderado como disparo de evaluación
    if (magnitude > _moderateImpactThreshold && _currentState == FallState.searching) {
      _currentState = FallState.impactDetected;
      _stateStartTime = now;
      _impactPeakTime = now;
      _maxImpactMagnitude = magnitude;
      debugPrint("IA AVANZADA: ¡POTENCIAL IMPACTO DE CAÍDA REGISTRADO! (G=${magnitude.toStringAsFixed(1)})");
    }

    switch (_currentState) {
      case FallState.searching:
        // Si entra en baja gravedad, se marca como posible caída en progreso
        if (magnitude < _freeFallThreshold) {
          _currentState = FallState.freeFallDetected;
          _stateStartTime = now;
          debugPrint("IA AVANZADA: Fase 1 - Caída libre iniciada (G=${magnitude.toStringAsFixed(1)})");
        }
        break;

      case FallState.freeFallDetected:
        // Si pasa demasiado tiempo sin golpe, cancelar
        if (now.difference(_stateStartTime!).inMilliseconds > 1200) {
          debugPrint("IA MULTIMODAL: Timeout en caída libre (G=${magnitude.toStringAsFixed(1)}), volviendo a buscar...");
          _currentState = FallState.searching;
          return false;
        }
        // Si hay un impacto severo tras la caída libre, registrar pico de impacto
        if (magnitude > _impactThreshold) {
          _currentState = FallState.impactDetected;
          _stateStartTime = now;
          _impactPeakTime = now;
          _maxImpactMagnitude = magnitude;
          debugPrint("IA MULTIMODAL: Fase 2 - ¡GOLPE TRAS CAÍDA LIBRE DETECTADO! (G=${magnitude.toStringAsFixed(1)})");
        }
        break;

      case FallState.impactDetected:
        // Mantener actualizado el valor y tiempo del pico más fuerte de impacto
        if (magnitude > _maxImpactMagnitude) {
          _maxImpactMagnitude = magnitude;
          _impactPeakTime = now;
        }

        // Esperar a que pase la ventana de observación post-impacto (2.5 segundos)
        if (now.difference(_stateStartTime!).inMilliseconds >= _postImpactObservationMs) {
          debugPrint("IA MULTIMODAL: Finalizada ventana de observación. Ejecutando Motor de Fusión Intermedia...");
          
          bool isConfirmedFall = _evaluateIntermediateFusion(_impactPeakTime ?? _stateStartTime!);
          
          // Resetear estado al terminar evaluación
          _currentState = FallState.searching;
          _impactPeakTime = null;
          _maxImpactMagnitude = 0.0;
          
          return isConfirmedFall;
        }
        break;

      default:
        _currentState = FallState.searching;
    }

    return false;
  }

  /// Limpia los buffers para retener solo los últimos _windowDurationMs milisegundos
  void _pruneBuffers(DateTime now) {
    final cutoff = now.subtract(const Duration(milliseconds: _windowDurationMs));
    while (_accBuffer.isNotEmpty && _accBuffer.first.time.isBefore(cutoff)) {
      _accBuffer.removeFirst();
    }
    while (_audioBuffer.isNotEmpty && _audioBuffer.first.time.isBefore(cutoff)) {
      _audioBuffer.removeFirst();
    }
  }

  /// Evalúa las características de la ventana temporal unificada usando Fusión Intermedia
  /// (Con soporte híbrido para Red Neuronal Convolucional TFLite y Heurística de Respaldo)
  bool _evaluateIntermediateFusion(DateTime impactTime) {
    // Si el modelo neuronal TFLite está cargado, lo prioriza
    if (_isModelLoaded && _interpreter != null) {
      try {
        debugPrint("IA EDGE: Ejecutando inferencia con Red Neuronal Convolucional (1D-CNN + 2D-CNN)...");
        return _evaluateCNNModel(impactTime);
      } catch (e) {
        debugPrint("IA EDGE ERROR: Fallo al ejecutar la Red Neuronal ($e). Usando heurística de respaldo...");
      }
    }

    // --- MOTOR DE RESPALDO HEURÍSTICO (FUSIÓN MATEMÁTICA INTERMEDIA) ---
    if (_accBuffer.isEmpty) return false;

    double freeFallScore = _calculateFreeFallScore(impactTime);
    double orientationScore = _calculateOrientationChangeScore(impactTime);
    double postImpactScore = _calculatePostImpactActivityScore(impactTime);
    double audioCoincidenceScore = _calculateAudioImpactCoincidenceScore(impactTime);
    double vocalizationScore = _calculatePostImpactVocalizationScore(impactTime);

    double wFreeFall = 0.30;
    double wOrientation = 0.25;
    double wPostImpact = 0.20;
    double wAudioImpact = 0.10;
    double wVocalization = 0.15;

    double jointProbability = (freeFallScore * wFreeFall) +
                             (orientationScore * wOrientation) +
                             (postImpactScore * wPostImpact) +
                             (audioCoincidenceScore * wAudioImpact) +
                             (vocalizationScore * wVocalization);

    // --- REGLAS FÍSICAS DE SUPRESIÓN DE FALSOS POSITIVOS ---
    // Regla 1: Una caída real del cuerpo humano requiere una fase mínima de ingravidez (caída libre).
    // Si no hay caída libre detectable (freeFallScore == 0.0), se penaliza fuertemente,
    // A MENOS que haya un cambio drástico de orientación y quietud absoluta (caída corta).
    if (freeFallScore < 0.1) {
      if (orientationScore > 0.8 && postImpactScore > 0.8) {
        if (_maxImpactMagnitude > 70.0) {
          debugPrint("IA MULTIMODAL AVISO: Impacto de golpe extremo sin caída libre. Bloqueado (golpe muy violento a mesa).");
          jointProbability *= 0.2;
        } else {
          debugPrint("IA MULTIMODAL AVISO: Falta de caída libre perdonada por postura y quietud absolutas (posible caída desde nivel bajo).");
          // Penalización mínima
          jointProbability *= 0.9;
        }
      } else {
        debugPrint("IA MULTIMODAL AVISO: Penalizando probabilidad por falta de caída libre (posible golpe estático).");
        jointProbability *= 0.4;
      }
    }

    // Regla 1.5: Si el dispositivo experimentó ingravidez casi PERFECTA, fue lanzado (proyectil).
    // Una persona cayendo siempre ejerce algo de resistencia, no llega a 0.0 G puros.
    if (_isProjectileDrop(impactTime)) {
      debugPrint("IA MULTIMODAL AVISO: Patrón de PROYECTIL detectado. El teléfono fue lanzado a una mesa/cama o cayó solo.");
      jointProbability *= 0.1; // Suprimir por completo
    }

    // Regla 2: Una caída real cambia la postura del paciente de vertical a horizontal.
    // Si el cambio de orientación 3D es nulo (orientationScore == 0.0), se penaliza.
    if (orientationScore < 0.1) {
      debugPrint("IA MULTIMODAL AVISO: Penalizando probabilidad por falta de cambio de postura angular.");
      jointProbability *= 0.4;
    }

    debugPrint("=== INFORME DE FUSIÓN INTERMEDIA HEURÍSTICA ===");
    debugPrint(" - Duración Caída Libre Score (30%): ${freeFallScore.toStringAsFixed(2)}");
    debugPrint(" - Cambio Orientación 3D Score (25%): ${orientationScore.toStringAsFixed(2)}");
    debugPrint(" - Quietud/Actividad Post Score (20%): ${postImpactScore.toStringAsFixed(2)}");
    debugPrint(" - Coincidencia Audio Pico Score (10%): ${audioCoincidenceScore.toStringAsFixed(2)}");
    debugPrint(" - Vocalización/Voz Post Score (15%): ${vocalizationScore.toStringAsFixed(2)}");
    debugPrint(" >> ÍNDICE DE PROBABILIDAD DE CAÍDA HUMANA (IPCH): ${jointProbability.toStringAsFixed(3)}");
    debugPrint("=========================================");

    bool isFall = jointProbability >= 0.65;
    if (isFall) {
      debugPrint("IA MULTIMODAL: ¡CAÍDA HUMANA DETECTADA Y CONFIRMADA MEDIANTE FUSIÓN INTERMEDIA! (IPCH: ${(jointProbability * 100).toStringAsFixed(1)}%)");
    } else {
      debugPrint("IA MULTIMODAL: Caída ignorada por baja probabilidad o salvaguarda física (IPCH: ${(jointProbability * 100).toStringAsFixed(1)}%). Falso positivo de caída.");
    }

    return isFall;
  }

  /// Ejecuta la inferencia de la Red Neuronal Convolucional de Fusión Intermedia usando TFLite
  bool _evaluateCNNModel(DateTime impactTime) {
    // 1. Convertir buffer del acelerómetro a Tensor [1, 250, 3] para la rama de movimiento (1D-CNN)
    var accTensor = _convertAccBufferToTensor(impactTime);

    // 2. Convertir buffer de audio a Tensor [1, 128, 1] para la rama acústica (Mel-spectrograma simplificado o serie temporal)
    var audioTensor = _convertAudioBufferToTensor();

    // 3. Empaquetar las entradas múltiples en una lista (Tensor 0: Audio, Tensor 1: Acelerómetro)
    List<Object> inputs = [audioTensor as Object, accTensor as Object];

    // 4. Crear estructura del tensor de salida: Probabilidad de caída humana [1, 1]
    var outputs = {
      0: List.generate(1, (_) => List.filled(1, 0.0))
    };

    // 5. Correr el intérprete localmente en el dispositivo
    _interpreter!.runForMultipleInputs(inputs, outputs);

    // 6. Extraer probabilidad
    double probability = outputs[0]![0][0];
    debugPrint("=========================================");
    debugPrint(" >> PROBABILIDAD DE CAÍDA POR RED NEURONAL: ${(probability * 100).toStringAsFixed(1)}%");
    debugPrint("=========================================");

    bool isFall = probability >= 0.70; // Umbral de confianza del modelo neuronal
    
    // Salvaguardas físicas deterministas para el modelo de red neuronal
    if (isFall) {
      double freeFallScore = _calculateFreeFallScore(impactTime);
      double orientationScore = _calculateOrientationChangeScore(impactTime);
      double postImpactScore = _calculatePostImpactActivityScore(impactTime);
      
      bool blockAlert = false;
      
      if (orientationScore < 0.1 || postImpactScore < 0.6) {
        blockAlert = true;
      } else if (freeFallScore < 0.1) {
        // Excepción para caída corta: Si hay un cambio de postura muy claro y se queda muy quieto,
        // perdonamos la falta de caída libre prolongada.
        if (orientationScore > 0.8 && postImpactScore > 0.8) {
          if (_maxImpactMagnitude > 70.0) {
            debugPrint("IA EDGE (CNN) AVISO: Impacto de golpe extremo sin caída libre. Bloqueado (golpe muy violento a mesa).");
            blockAlert = true;
          } else {
            debugPrint("IA EDGE (CNN) INFO: Falta de caída libre perdonada por postura y quietud absolutas (posible caída corta).");
          }
        } else {
          blockAlert = true;
        }
      }

      // Proyectil Salvaguarda: Lanzar el teléfono a la cama/mesa genera gravedad cero pura.
      if (_isProjectileDrop(impactTime)) {
        debugPrint("IA EDGE (CNN) AVISO: Patrón de PROYECTIL (Gravedad cero perfecta). El teléfono fue lanzado a una cama/mesa.");
        blockAlert = true;
      }

      if (blockAlert) {
        debugPrint("IA EDGE (CNN) AVISO: La red dio positivo, pero se bloqueó por salvaguarda física (FF: ${freeFallScore.toStringAsFixed(2)}, OR: ${orientationScore.toStringAsFixed(2)}, PI: ${postImpactScore.toStringAsFixed(2)}).");
        isFall = false;
      }
    }

    if (isFall) {
      debugPrint("IA EDGE (CNN): ¡CAÍDA CONFIRMADA POR RED NEURONAL MULTIMODAL CON INTERMEDIATE FUSION! (Probabilidad: ${(probability * 100).toStringAsFixed(1)}%)");
    } else {
      debugPrint("IA EDGE (CNN): Caída ignorada por baja probabilidad o salvaguarda física (Probabilidad: ${(probability * 100).toStringAsFixed(1)}%). Falso positivo de caída.");
    }

    return isFall;
  }

  /// Convierte el búfer dinámico del acelerómetro a una forma estática [1, 250, 3] esperada por la 1D-CNN
  List<List<List<double>>> _convertAccBufferToTensor(DateTime impactTime) {
    const int targetLength = 250; // Longitud esperada por el modelo (5 segundos a 50Hz)
    
    // Ventana temporal centrada en el impacto (3.5 segundos antes, 1.5 segundos después)
    final windowStart = impactTime.subtract(const Duration(milliseconds: 3500));
    final windowEnd = impactTime.add(const Duration(milliseconds: 1500));

    List<AccelerometerEntry> selectedSamples = [];
    for (var entry in _accBuffer) {
      if (entry.time.isAfter(windowStart) && entry.time.isBefore(windowEnd)) {
        selectedSamples.add(entry);
      }
    }

    // Rellenar o recortar las muestras para tener exactamente 250 elementos (Padded Temporal Interpolation)
    List<List<double>> outputSequence = [];
    if (selectedSamples.isEmpty) {
      // Si el búfer está vacío, rellenamos con gravedad estática en eje Z
      outputSequence = List.generate(targetLength, (_) => [0.0, 0.0, 9.8]);
    } else if (selectedSamples.length < targetLength) {
      // Duplicar el último elemento como padding si hay menos muestras
      for (int i = 0; i < targetLength; i++) {
        int index = i < selectedSamples.length ? i : selectedSamples.length - 1;
        outputSequence.add([
          selectedSamples[index].x,
          selectedSamples[index].y,
          selectedSamples[index].z
        ]);
      }
    } else {
      // Recortar si hay más
      for (int i = 0; i < targetLength; i++) {
        outputSequence.add([
          selectedSamples[i].x,
          selectedSamples[i].y,
          selectedSamples[i].z
        ]);
      }
    }

    // Encapsular en la dimensión de lote (Batch Size = 1) -> [1, 250, 3]
    return [outputSequence];
  }

  final bool _useSpectrogramMode = true; // ACTIVADO: Usa el nuevo modelo_fusion2.tflite

  /// Convierte el búfer de decibelios continuos a la forma esperada por la red
  dynamic _convertAudioBufferToTensor() {
    const int targetLength = 128; // Ventana temporal
    
    List<double> dbList = _audioBuffer.map((e) => e.db).toList();

    if (_useSpectrogramMode) {
      // IMPLEMENTACIÓN REAL DE ESPECTROGRAMA (FFT)
      List<AudioEntry> audioList = _audioBuffer.toList(); // Convertir Queue a List
      List<List<List<double>>> realSpectrogram = [];
      
      for (int f = 0; f < 128; f++) {
        List<List<double>> row = [];
        for (int t = 0; t < targetLength; t++) {
          double val = 45.0; // Ruido base si no hay datos
          if (audioList.length > t) {
            if (audioList[t].frequencies != null && audioList[t].frequencies!.length > f) {
              val = audioList[t].frequencies![f];
            } else {
              val = audioList[t].db; // fallback
            }
          }
          row.add([val]);
        }
        realSpectrogram.add(row);
      }
      return [realSpectrogram]; // [1, 128, 128, 1]
    }

    // Relleno estático / Interpolación lineal de decibelios a 128 características temporales
    List<List<double>> outputSequence = [];
    if (dbList.isEmpty) {
      outputSequence = List.generate(targetLength, (_) => [45.0]); // Ruido base promedio de 45 dB
    } else if (dbList.length < targetLength) {
      // Padding
      for (int i = 0; i < targetLength; i++) {
        int index = i < dbList.length ? i : dbList.length - 1;
        outputSequence.add([dbList[index]]);
      }
    } else {
      // Recortar
      for (int i = 0; i < targetLength; i++) {
        outputSequence.add([dbList[i]]);
      }
    }

    // Encapsular en Batch y Canal -> [1, 128, 1]
    return [outputSequence];
  }

  /// Calcula la puntuación del patrón de caída libre en los 1.5s previos al impacto
  double _calculateFreeFallScore(DateTime impactTime) {
    double maxContiguousMs = 0;
    double contiguousMs = 0;
    AccelerometerEntry? prevEntry;

    final windowStart = impactTime.subtract(const Duration(milliseconds: 1500));

    for (var entry in _accBuffer) {
      if (entry.time.isBefore(windowStart) || entry.time.isAfter(impactTime)) {
        continue;
      }

      if (prevEntry != null) {
        double deltaMs = entry.time.difference(prevEntry.time).inMilliseconds.toDouble();
        if (deltaMs > 250) deltaMs = 250; // Limitar deltas gigantes si la app se suspendió

        if (entry.magnitude < 4.0) { // Umbral de baja gravedad más estricto
          contiguousMs += deltaMs;
          if (contiguousMs > maxContiguousMs) {
            maxContiguousMs = contiguousMs;
          }
        } else {
          contiguousMs = 0;
        }
      }
      prevEntry = entry;
    }

    // Una caída real requiere al menos 150 ms de baja gravedad contigua (ingravidez).
    if (maxContiguousMs >= 200 && maxContiguousMs <= 700) {
      return 1.0;
    } else if (maxContiguousMs > 700 && maxContiguousMs < 1100) {
      return 1.0 - ((maxContiguousMs - 700) / 400);
    } else if (maxContiguousMs >= 150 && maxContiguousMs < 200) {
      return (maxContiguousMs - 150) / 50; // Rango de transición corto
    }

    return 0.0;
  }

  /// Verifica si el dispositivo experimentó ingravidez perfecta (Lanzamiento / Caída libre suelta).
  /// El cuerpo humano cayendo presenta resistencia (2.0 a 5.0 m/s²), pero un teléfono suelto baja de 1.5 m/s².
  bool _isProjectileDrop(DateTime impactTime) {
    double minGravity = 9.8;
    int projectileSamples = 0;
    
    final start = impactTime.subtract(const Duration(milliseconds: 1500));
    final end = impactTime.add(const Duration(milliseconds: 200));

    for (var entry in _accBuffer) {
      if (entry.time.isAfter(start) && entry.time.isBefore(end)) {
        if (entry.magnitude < minGravity) {
          minGravity = entry.magnitude;
        }
        // Menos de 2.0 m/s² (aprox 0.2 G) es ingravidez casi perfecta
        if (entry.magnitude < 2.0) {
          projectileSamples++;
        }
      }
    }
    
    // Si el teléfono estuvo en ingravidez perfecta por más de ~60-80ms (3-4 muestras a 50Hz)
    if (minGravity < 2.0 && projectileSamples >= 3) {
      return true;
    }
    return false;
  }

  /// Calcula el cambio de postura midiendo la variación angular del vector de gravedad 3D antes y después
  double _calculateOrientationChangeScore(DateTime impactTime) {
    double sumXPre = 0, sumYPre = 0, sumZPre = 0;
    int countPre = 0;
    final preStart = impactTime.subtract(const Duration(milliseconds: 3000));
    final preEnd = impactTime.subtract(const Duration(milliseconds: 1500));

    double sumXPost = 0, sumYPost = 0, sumZPost = 0;
    int countPost = 0;
    final postStart = impactTime.add(const Duration(milliseconds: 1000));
    final postEnd = impactTime.add(const Duration(milliseconds: 2500));

    for (var entry in _accBuffer) {
      if (entry.time.isAfter(preStart) && entry.time.isBefore(preEnd)) {
        sumXPre += entry.x;
        sumYPre += entry.y;
        sumZPre += entry.z;
        countPre++;
      } else if (entry.time.isAfter(postStart) && entry.time.isBefore(postEnd)) {
        sumXPost += entry.x;
        sumYPost += entry.y;
        sumZPost += entry.z;
        countPost++;
      }
    }

    if (countPre == 0 || countPost == 0) return 0.5;

    double avgXPre = sumXPre / countPre;
    double avgYPre = sumYPre / countPre;
    double avgZPre = sumZPre / countPre;

    double avgXPost = sumXPost / countPost;
    double avgYPost = sumYPost / countPost;
    double avgZPost = sumZPost / countPost;

    double dotProduct = (avgXPre * avgXPost) + (avgYPre * avgYPost) + (avgZPre * avgZPost);
    double magPre = sqrt(avgXPre * avgXPre + avgYPre * avgYPre + avgZPre * avgZPre);
    double magPost = sqrt(avgXPost * avgXPost + avgYPost * avgYPost + avgZPost * avgZPost);

    if (magPre < 0.1 || magPost < 0.1) return 0.0;

    double cosTheta = dotProduct / (magPre * magPost);
    cosTheta = max(-1.0, min(1.0, cosTheta));
    
    double angleRad = acos(cosTheta);
    double angleDeg = angleRad * (180 / pi);

    debugPrint("IA CÁLCULO POSTURA: Cambio angular de orientación = ${angleDeg.toStringAsFixed(1)}°");

    if (angleDeg > 40.0) {
      return 1.0;
    } else if (angleDeg < 15.0) {
      return 0.0;
    } else {
      return (angleDeg - 15.0) / 25.0;
    }
  }

  /// Mide la quietud y descarta alertas si la persona sigue caminando o corriendo activamente post-impacto
  double _calculatePostImpactActivityScore(DateTime impactTime) {
    final start = impactTime.add(const Duration(milliseconds: 500));
    final end = impactTime.add(const Duration(milliseconds: 2500));

    List<double> magnitudes = [];
    double sum = 0;

    for (var entry in _accBuffer) {
      if (entry.time.isAfter(start) && entry.time.isBefore(end)) {
        magnitudes.add(entry.magnitude);
        sum += entry.magnitude;
      }
    }

    if (magnitudes.isEmpty) return 0.5;

    double avg = sum / magnitudes.length;
    double varianceSum = 0;
    for (var m in magnitudes) {
      varianceSum += (m - avg) * (m - avg);
    }
    double stdDev = sqrt(varianceSum / magnitudes.length);

    debugPrint("IA CÁLCULO ACTIVIDAD: Desviación estándar post-impacto = ${stdDev.toStringAsFixed(2)} m/s²");

    if (stdDev > 4.0) {
      return 0.0;
    } else if (stdDev < 1.2) {
      return 1.0;
    } else if (stdDev >= 1.2 && stdDev <= 2.5) {
      return 0.9;
    } else {
      return 1.0 - ((stdDev - 1.2) / 2.8);
    }
  }

  /// Comprueba si hay un pico sonoro coincidente con el impacto mecánico
  double _calculateAudioImpactCoincidenceScore(DateTime impactTime) {
    double maxDb = 0.0;
    final start = impactTime.subtract(const Duration(milliseconds: 200));
    final end = impactTime.add(const Duration(milliseconds: 300));

    for (var entry in _audioBuffer) {
      if (entry.time.isAfter(start) && entry.time.isBefore(end)) {
        if (entry.db > maxDb) {
          maxDb = entry.db;
        }
      }
    }

    debugPrint("IA CÁLCULO AUDIO IMPACTO: Pico sonoro detectado = ${maxDb.toStringAsFixed(1)} dB");

    if (maxDb > 75.0) {
      return 1.0;
    } else if (maxDb > 55.0) {
      return (maxDb - 55.0) / 20.0;
    }
    return 0.2;
  }

  /// Evalúa la presencia de quejidos o voz humana post-impacto (0.5s a 2.5s después)
  double _calculatePostImpactVocalizationScore(DateTime impactTime) {
    final start = impactTime.add(const Duration(milliseconds: 500));
    final end = impactTime.add(const Duration(milliseconds: 2500));

    List<double> dbLevels = [];
    double sum = 0;

    for (var entry in _audioBuffer) {
      if (entry.time.isAfter(start) && entry.time.isBefore(end)) {
        dbLevels.add(entry.db);
        sum += entry.db;
      }
    }

    if (dbLevels.isEmpty) return 0.5;

    double avgDb = sum / dbLevels.length;

    double varianceSum = 0;
    for (var db in dbLevels) {
      varianceSum += (db - avgDb) * (db - avgDb);
    }
    double stdDevDb = sqrt(varianceSum / dbLevels.length);

    debugPrint("IA CÁLCULO VOCES: Promedio dB post = ${avgDb.toStringAsFixed(1)} dB (stdDev = ${stdDevDb.toStringAsFixed(2)})");

    if (avgDb >= 52.0 && avgDb <= 78.0) {
      if (stdDevDb > 2.0) {
        return 1.0;
      } else {
        return 0.8;
      }
    } else if (avgDb < 45.0) {
      return 0.5;
    } else {
      return 0.3;
    }
  }

  /// Detecta si el teléfono está siendo agitado violentamente
  bool detectShaking(double x, double y, double z) {
    if (_accBuffer.isEmpty) return false;

    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));

    int highAccelerationCount = 0;
    for (var entry in _accBuffer) {
      if (entry.time.isAfter(oneSecondAgo)) {
        if (entry.magnitude > _shakeThreshold) {
          highAccelerationCount++;
        }
      }
    }

    // Un solo impacto contra la cama suele durar de 1 a 3 muestras (muy rápido).
    // Para considerarse agitación violenta sostenida, requerimos al menos 35 muestras
    // por encima de _shakeThreshold m/s² en el último segundo.
    if (highAccelerationCount >= 35) {
      debugPrint("IA MULTIMODAL: ¡AGITACIÓN VIOLENTA DETECTADA! (Muestras altas=$highAccelerationCount en el último segundo)");
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
