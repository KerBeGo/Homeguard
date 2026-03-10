import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/medication_model.dart';
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
    try {
      final dynamic timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
    }

    // Reemplaza '@mipmap/ic_launcher' por el ícono de la app si tienes otro
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        final payload = response.payload;
        if (payload != null) {
          // You could use a GlobalKey<NavigatorState> to navigate to the confirmation screen
          debugPrint('Notification tapped with payload: $payload');
        }
      },
    );

    // Request permissions for Android 13+
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleReminders(List<Medication> medications) async {
    await flutterLocalNotificationsPlugin.cancelAll();

    for (var med in medications) {
      if (!med.activo || med.horas.isEmpty) continue;

      for (var horaStr in med.horas) {
        final parts = horaStr.split(':');
        final int hour = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);

        final int uniqueId = (med.id?.hashCode ?? 0) + hour * 60 + minute;

        await _scheduleDailyNotification(
          id: uniqueId,
          title: 'Hora de tu medicamento: ${med.nombre}',
          body: '${med.categoria} - ${med.descripcion}',
          hour: hour,
          minute: minute,
          payload: med.id,
        );
      }
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel_id',
            'Medication Reminders',
            channelDescription: 'Recordatorios de medicinas',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode
            .inexactAllowWhileIdle, // Fallback to inexact to avoid SecurityException on Android 14+ if exact alarms are denied
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      debugPrint("ALARM SCHEDULED SUCCESSFULLY: $title for $hour:$minute");
    } catch (e) {
      debugPrint("ERROR SCHEDULING ALARM: $e");
    }
  }

  // ADDING THIS DEBUG METHOD TO TEST NOTIFICATIONS IMMEDIATELY
  Future<void> showDebugNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'debug_channel_id',
          'Debug Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 9999,
      title: 'Test de Alarma',
      body: 'Si ves esto, las notificaciones funcionan',
      notificationDetails: platformChannelSpecifics,
      payload: 'item x',
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
