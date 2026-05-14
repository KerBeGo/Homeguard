import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sensor_service.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  bool _isMonitoring = false;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    var status = await Permission.microphone.status;
    debugPrint("SENSOR DE SONIDO: Estado del permiso micrófono: $status");

    if (status.isDenied) {
      debugPrint("SENSOR DE SONIDO: Solicitando permiso...");
      status = await Permission.microphone.request();
      debugPrint("SENSOR DE SONIDO: Resultado solicitud: $status");
    }

    if (status.isGranted) {
      try {
        // CONFIGURACIÓN DE SESIÓN DE AUDIO PARA SEGUNDO PLANO
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.measurement,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ));
        await session.setActive(true);
        debugPrint("SENSOR DE SONIDO: Sesión de audio activada para fondo.");

        _noiseMeter = NoiseMeter();
        debugPrint("SENSOR DE SONIDO: Preparando micrófono...");

        // Pequeño retraso para asegurar que el hardware esté listo tras el permiso
        Future.delayed(const Duration(seconds: 1), () {
          _noiseSubscription = _noiseMeter!.noise.listen(
            (NoiseReading noiseReading) {
              double db = noiseReading.maxDecibel;

              if (db != double.negativeInfinity) {
                // Notificar al SensorService
                SensorService().handleAudioUpdate(db);

                // Log de monitoreo profesional
                debugPrint("MONITOR AUDIO -> ${db.toStringAsFixed(1)} dB");
              }
            },
            onError: (Object error) {
              debugPrint("ERROR EN STREAM DE SONIDO: $error");
            },
          );
          _isMonitoring = true;
          debugPrint("SENSOR DE SONIDO: Monitoreo activo y escuchando.");
        });
      } catch (e) {
        debugPrint("ERROR AL INICIAR SENSOR DE SONIDO: $e");
      }
    } else {
      debugPrint(
        "SENSOR DE SONIDO: No se puede iniciar porque el permiso es $status",
      );
    }
  }

  void stopMonitoring() {
    _noiseSubscription?.cancel();
    _isMonitoring = false;
  }
}
