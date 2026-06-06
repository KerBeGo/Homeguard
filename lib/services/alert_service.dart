import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alerts_model.dart';
import 'local_notification_service.dart';
import 'package:another_telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> enviarAlerta({
    required String tipo,
    required String mensaje,
    bool mostrarNotificacionLocal = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (mostrarNotificacionLocal) {
      // Feedback local inmediato (Funciona aunque no haya internet)
      await LocalNotificationService().sendInstantNotification(
        'ALERTA DETECTADA: ${tipo.toUpperCase()}',
        mensaje,
      );
    }

    // Luego intentar sincronizar con la nube...
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final nombrePaciente = data['nombre'] ?? 'Paciente';
    final cuidadorId = data['cuidadorId'];

    if (cuidadorId == null) {
      // print("No hay cuidador vinculado para enviar la alerta");
      // En una aplicación real, podrías querer manejar esto de forma diferente
      // (ej: enviar a una lista general o notificar al paciente)
      return;
    }

    final nuevaAlerta = AlertModel(
      tipo: tipo,
      mensaje: mensaje,
      pacienteId: user.uid,
      pacienteNombre: nombrePaciente,
      cuidadorId: cuidadorId,
      timestamp: DateTime.now(),
    );

    try {
      // Firestore guarda en caché local automáticamente si no hay internet
      _firestore.collection('alertas').add(nuevaAlerta.toMap());

      // Verificamos explícitamente si hay conexión a internet real
      bool hasInternet = await _hasInternetConnection();
      if (!hasInternet) {
        debugPrint("NO HAY INTERNET: Enviando SMS de emergencia localmente...");
        await _enviarSmsDeEmergencia(tipo, mensaje, user.uid);
      }
    } catch (e) {
      // Si falla Firestore (posiblemente offline), intentamos SMS de respaldo
      await _enviarSmsDeEmergencia(tipo, mensaje, user.uid);
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enviarSmsDeEmergencia(String tipo, String mensaje, String uid) async {
    try {
      // 1. Obtener datos del paciente localmente
      String? telefonoCuidador;
      
      try {
        final doc = await _firestore.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          telefonoCuidador = data['cuidadorTelefono'];
        }
      } catch (_) {}

      // Fallback a SharedPreferences si no hay cache
      if (telefonoCuidador == null || telefonoCuidador.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        telefonoCuidador = prefs.getString('cuidadorTelefono');
      }
      
      if (telefonoCuidador == null || telefonoCuidador.isEmpty) {
        debugPrint("ERROR OFFLINE: No hay teléfono de cuidador guardado localmente.");
        return;
      }

      // 2. Obtener ubicación actual (con timeout para que no se quede pegado)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        // Fallback a la última ubicación conocida
        debugPrint("Timeout de GPS, buscando última ubicación conocida...");
        position = await Geolocator.getLastKnownPosition();
      }

      // 3. Preparar mensaje SIN TILDES NI CARACTERES ESPECIALES
      // Si un SMS tiene tildes (ej: ó, ñ), el límite baja de 160 a 70 caracteres
      // y si lo supera, Android lo descarta silenciosamente.
      String ubicacionTexto = "Ubicacion no disponible";
      if (position != null) {
        ubicacionTexto = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
      }
      
      String mensajeLimpio = mensaje.replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n').replaceAll('¡', '').replaceAll('¿', '');
      String smsMensaje = "HOMEGUARD ALERTA: ${tipo.toUpperCase()}\n$mensajeLimpio\nUbicacion: $ubicacionTexto";

      // Limitar a 150 caracteres por seguridad
      if (smsMensaje.length > 150) {
        smsMensaje = smsMensaje.substring(0, 150);
      }

      // 4. Formatear número venezolano a estándar internacional (+58)
      // Android a veces falla al enrutar SMS programáticos con números locales (0412, 0424)
      String numeroFormateado = telefonoCuidador.trim();
      if (numeroFormateado.startsWith('04')) {
        numeroFormateado = '+58${numeroFormateado.substring(1)}';
      }

      // 5. Enviar SMS (Solo Android)
      if (Platform.isAndroid) {
        final Telephony telephony = Telephony.instance;
        bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
        
        if (permissionsGranted == true) {
          await telephony.sendSms(
            to: numeroFormateado,
            message: smsMensaje,
          );
          debugPrint("SMS de emergencia enviado correctamente a $numeroFormateado con texto: $smsMensaje");
        } else {
          debugPrint("ERROR: Permisos de SMS denegados");
        }
      }
    } catch (e) {
      debugPrint("ERROR AL ENVIAR SMS DE EMERGENCIA: $e");
    }
  }

  Future<void> forzarSmsDePrueba(String tipo, String mensaje) async {
    final user = _auth.currentUser;
    if (user != null) {
      debugPrint("Forzando envío de SMS de prueba...");
      await _enviarSmsDeEmergencia(tipo, mensaje, user.uid);
    } else {
      debugPrint("Error forzando SMS: Usuario no logueado");
    }
  }
}
