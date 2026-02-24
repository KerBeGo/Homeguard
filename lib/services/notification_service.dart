import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';

// Esta función debe ser de nivel superior (fuera de la clase) para manejar mensajes en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log("Manejando un mensaje en segundo plano: ${message.messageId}");
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Configurar el manejador de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Pedir permisos
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('Permiso concedido');
    } else {
      log('Permiso denegado');
    }

    // 3. Obtener el token FCM
    String? token = await _fcm.getToken();
    if (token != null) {
      log('FCM Token: $token');
      await _saveTokenToFirestore(token);
    }

    // 4. Escuchar refrescos de token
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // 5. Manejar mensajes cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('¡Mensaje recibido en primer plano!');
      log('Datos del mensaje: ${message.data}');

      if (message.notification != null) {
        log(
          'El mensaje también contenía una notificación: ${message.notification?.title}',
        );
      }
    });

    // 6. Manejar cuando el usuario TOCA la notificación y la app estaba en segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('El usuario tocó la notificación!');
      // Aquí podrías navegar a la pantalla de alertas si fuera necesario
    });

    // 7. Manejar si la app se abrió desde una notificación estando CERRADA
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      log('La app se abrió desde una notificación (estando cerrada)');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        log('Token FCM guardado en Firestore');
      } catch (e) {
        log('Error al guardar token: $e');
      }
    } else {
      log('No hay usuario logueado, token no guardado');
    }
  }
}
