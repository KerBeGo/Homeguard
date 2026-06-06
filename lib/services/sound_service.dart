import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'sensor_service.dart';

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioRecorder _record = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final FFT _fft = FFT(256); // 256 puntos -> 128 frecuencias

  bool _isMonitoring = false;
  final List<int> _audioBuffer = [];

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
        debugPrint("SENSOR DE SONIDO: Sesión de audio activada.");

        if (await _record.hasPermission()) {
          final stream = await _record.startStream(const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ));

          _audioStreamSubscription = stream.listen((data) {
            // Usamos ByteData para leer los enteros de 16-bits de forma segura, 
            // saltándonos el problema de alineación de memoria (Offset múltiple de 2).
            final byteData = ByteData.sublistView(data);
            final int numSamples = data.length ~/ 2;

            for (int i = 0; i < numSamples; i++) {
              // Leer cada muestra como un entero de 16 bits (Little Endian es el estándar PCM)
              int sample = byteData.getInt16(i * 2, Endian.little);
              _audioBuffer.add(sample);
              
              if (_audioBuffer.length == 256) {
                _processFftFrame(_audioBuffer);
                _audioBuffer.clear();
              }
            }
          });

          _isMonitoring = true;
          debugPrint("SENSOR DE SONIDO: FFT Activo (16kHz, 256 puntos).");
        }
      } catch (e) {
        debugPrint("ERROR AL INICIAR SENSOR DE SONIDO: $e");
      }
    } else {
      debugPrint("SENSOR DE SONIDO: Permiso denegado $status");
    }
  }

  void _processFftFrame(List<int> frame) {
    // Normalizar a flotantes (-1.0 a 1.0) y calcular la media (DC Offset)
    double sum = 0.0;
    for (int i = 0; i < 256; i++) {
      sum += frame[i].toDouble() / 32768.0;
    }
    double mean = sum / 256.0;

    final Float64List floatFrame = Float64List(256);
    double sumSquares = 0.0;

    for (int i = 0; i < 256; i++) {
      // Restar la media para eliminar el offset de corriente continua del micrófono físico
      double val = (frame[i].toDouble() / 32768.0) - mean;
      floatFrame[i] = val;
      sumSquares += val * val;
    }

    // Calcular volumen global real (RMS) limpio
    double rms = sqrt(sumSquares / 256.0);
    double realVolumeDb = 0.0;
    if (rms > 1e-6) {
      realVolumeDb = 20 * log(rms) / ln10;
      realVolumeDb = realVolumeDb + 100.0; // Escalar aproximado SPL
      if (realVolumeDb < 0) realVolumeDb = 0.0;
      if (realVolumeDb > 120) realVolumeDb = 120.0;
    }

    // Calcular FFT (Magnitudes de 129 bins, usamos 128)
    final magnitudes = _fft.realFft(floatFrame).magnitudes();

    List<double> dbFrequencies = [];

    for (int i = 0; i < 128; i++) {
      double mag = magnitudes[i];
      // Convertir a Decibelios para la red neuronal
      double db = 20 * log(max(mag, 1e-6)) / ln10;
      db = db + 100.0; 
      if (db < 0) db = 0;
      if (db > 120) db = 120;
      
      dbFrequencies.add(db);
    }

    // Enviamos al IA Service el Volumen Máximo RMS y las 128 bandas
    SensorService().handleAudioUpdate(realVolumeDb, dbFrequencies);
  }

  void stopMonitoring() {
    _audioStreamSubscription?.cancel();
    _record.stop();
    _isMonitoring = false;
  }
}
