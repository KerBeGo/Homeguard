import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alerts_model.dart';
import 'local_notification_service.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> enviarAlerta({
    required String tipo,
    required String mensaje,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Feedback local inmediato (Funciona aunque no haya internet)
    await LocalNotificationService().sendInstantNotification(
      'ALERTA DETECTADA: ${tipo.toUpperCase()}',
      mensaje,
    );

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
      await _firestore.collection('alertas').add(nuevaAlerta.toMap()).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Si falla Firestore (posiblemente offline), intentamos SMS de respaldo
      await _enviarSmsDeEmergencia(tipo, mensaje, user.uid);
    }

    // Feedback local para el paciente (Funciona offline)
    await LocalNotificationService().sendInstantNotification(
      'Alerta Detectada: ${tipo.toUpperCase()}',
      mensaje,
    );
  }

  Future<void> _enviarSmsDeEmergencia(String tipo, String mensaje, String uid) async {
    try {
      // 1. Obtener datos del paciente localmente (si es posible)
      final doc = await _firestore.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final telefonoCuidador = data['cuidadorTelefono'];
      
      if (telefonoCuidador == null || telefonoCuidador.isEmpty) {
        debugPrint("ERROR OFFLINE: No hay teléfono de cuidador guardado localmente.");
        return;
      }

      // 2. Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3. Preparar mensaje
      String googleMapsUrl = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
      String smsMensaje = "HOMEGUARD ALERTA: ${tipo.toUpperCase()}\n$mensaje\nUbicación: $googleMapsUrl";

      // 4. Enviar SMS (Solo Android)
      if (Platform.isAndroid) {
        final Telephony telephony = Telephony.instance;
        bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
        
        if (permissionsGranted == true) {
          await telephony.sendSms(
            to: telefonoCuidador,
            message: smsMensaje,
          );
          debugPrint("SMS de emergencia enviado correctamente.");
        }
      }
    } catch (e) {
      debugPrint("ERROR AL ENVIAR SMS DE EMERGENCIA: $e");
    }
  }
}
