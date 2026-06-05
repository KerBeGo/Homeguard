import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:typed_data';
import '../models/medication_model.dart';

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

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
      'alertas_criticas_v2',
      'Alertas Críticas',
      channelDescription: 'Notificaciones de emergencia (Caídas, Gritos)',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
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

  Future<void> scheduleReminders(dynamic dynamicMedications) async {
    List<Medication> medications = dynamicMedications as List<Medication>;

    // Obtener notificaciones pendientes
    final List<PendingNotificationRequest> pending =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    // Cancelar solo los recordatorios de medicamentos antiguos para no duplicarlos
    for (var request in pending) {
      if (request.payload == 'medication_reminder') {
        await flutterLocalNotificationsPlugin.cancel(id: request.id);
      }
    }

    final Int32List insistentFlag = Int32List.fromList(<int>[4]); // FLAG_INSISTENT

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_channel_v3',
      'Recordatorios de Medicamentos',
      channelDescription: 'Avisos para tomar tus pastillas y medicinas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('pastilla_audio'),
      additionalFlags: insistentFlag,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final now = tz.TZDateTime.now(tz.local);

    for (var med in medications) {
      if (!med.activo) continue;

      for (int i = 0; i < med.horas.length; i++) {
        String horaStr = med.horas[i];
        List<String> parts = horaStr.split(':');
        if (parts.length != 2) continue;

        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        tz.TZDateTime scheduledDate = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, minute,
        );

        // Si la hora ya pasó hoy, programar para mañana
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        int uniqueId = med.notificationId + i; // Generar ID único por hora

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: uniqueId,
          title: 'Hora de tu medicamento',
          body: 'Es hora de tomar: ${med.nombre}',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // Repite diario a esta hora
          payload: 'medication_reminder',
        );
      }
    }
    debugPrint("NOTIFICACIONES: Recordatorios de medicamentos programados (${medications.length} activos).");
  }

  Future<void> scheduleAppointmentNotification({
    required int id,
    required String doctor,
    required String especialidad,
    required DateTime scheduledDate,
  }) async {
    final Int32List insistentFlag = Int32List.fromList(<int>[4]); // FLAG_INSISTENT

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'appointment_channel_v3',
      'Recordatorios de Citas Médicas',
      channelDescription: 'Avisos de citas programadas',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('cita_audio'),
      additionalFlags: insistentFlag,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final tz.TZDateTime appointmentDate = tz.TZDateTime.from(scheduledDate, tz.local);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // 1. Alerta 1 día antes
    final tz.TZDateTime unDiaAntes = appointmentDate.subtract(const Duration(days: 1));
    if (unDiaAntes.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id * 10 + 1, // Unique ID derivado
        title: 'Cita Médica Mañana',
        body: 'Mañana tienes cita de $especialidad con el Dr(a). $doctor a las ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}.',
        scheduledDate: unDiaAntes,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment_reminder',
      );
    }

    // 2. Alerta 2 horas antes (el mismo día)
    final tz.TZDateTime dosHorasAntes = appointmentDate.subtract(const Duration(hours: 2));
    if (dosHorasAntes.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id * 10 + 2, // Unique ID derivado
        title: 'Cita Médica en 2 horas',
        body: 'Recuerda tu cita de $especialidad con el Dr(a). $doctor.',
        scheduledDate: dosHorasAntes,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'appointment_reminder',
      );
    }


    debugPrint("NOTIFICACIONES: Cita médica programada exitosamente para $doctor.");
  }
}
