import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // No necesitamos setLocalLocation(tz.getLocation('UTC')) si usamos zonas locales,
    // pero para compatibilidad con el código anterior lo dejamos o usamos la zona del dispositivo.

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Notificación clickeada: ${details.payload}");
      },
    );
    debugPrint("NOTIFICACIONES: Sistema inicializado correctamente.");
  }

  Future<void> sendInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'alertas_criticas_v1',
      'Alertas Críticas',
      channelDescription: 'Notificaciones de emergencia (Caídas, Gritos)',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ticker: 'Alerta Crítica',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, // ID único basado en tiempo
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'alerta_caida',
    );
    debugPrint("ALERTA: Notificación enviada -> $title");
  }

  Future<void> scheduleReminders(dynamic medications) async {}
  Future<void> scheduleAppointmentNotification({required int id, required String doctor, required String especialidad, required DateTime scheduledDate}) async {}
}
