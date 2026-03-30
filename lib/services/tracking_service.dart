import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'alert_service.dart';
import 'geofence_service.dart';
import 'dart:developer';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStateStream;
  Timer? _batteryLevelTimer;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  final Battery _battery = Battery();
  final AlertService _alertService = AlertService();
  final GeofenceService _geofenceService = GeofenceService();
  DateTime? _lastGeofenceAlertTime;

  // Creamos un stream controller o notificador simple si se requiere, pero podemos
  // manejar las callbacks directas para la UI de HomePaciente.
  Function(String, bool)? onStatusChange;

  Future<void> startMonitoring() async {
    if (_isTracking) {
      _notifyListeners("Monitoreo Activo", true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _notifyListeners("Usuario no autenticado", false);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _notifyListeners("Ubicación desactivada", false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _notifyListeners("Permiso de ubicación denegado", false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _notifyListeners("Permiso denegado permanentemente", false);
      return;
    }

    if (permission == LocationPermission.whileInUse) {
      // Requerir permiso "Siempre" para mejor monitoreo en background
      await Geolocator.requestPermission();
    }

    _isTracking = true;
    _notifyListeners("Monitoreo Activo", true);

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Monitoreando ubicación en segundo plano.",
          notificationTitle: "Homeguard Activado",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLocation(user.uid, position);
          },
        );

    _batteryStateStream = _battery.onBatteryStateChanged.listen((
      BatteryState state,
    ) {
      _updateBattery(user.uid);
    });

    _updateBattery(user.uid);
    _batteryLevelTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _updateBattery(user.uid),
    );
  }

  void stopMonitoring() {
    _positionStream?.cancel();
    _batteryStateStream?.cancel();
    _batteryLevelTimer?.cancel();

    _positionStream = null;
    _batteryStateStream = null;
    _batteryLevelTimer = null;

    _isTracking = false;
    _notifyListeners("Monitoreo Detenido", false);
  }

  void _notifyListeners(String status, bool tracking) {
    if (onStatusChange != null) {
      onStatusChange!(status, tracking);
    }
  }

  Future<void> _updateLocation(String uid, Position position) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      bool isOutside = await _geofenceService.isPointOutsideAllGeofences(
        uid,
        GeoPoint(position.latitude, position.longitude),
      );

      if (isOutside) {
        if (_lastGeofenceAlertTime == null ||
            DateTime.now().difference(_lastGeofenceAlertTime!) >
                const Duration(minutes: 30)) {
          _lastGeofenceAlertTime = DateTime.now();
          await _alertService.enviarAlerta(
            tipo: "zona_segura",
            mensaje:
                "Alerta Automática: El paciente ha salido de la zona segura.",
          );
        }
      }
    } catch (e) {
      log("Error al verificar geocercas/ubicacion: $e");
    }
  }

  Future<void> _updateBattery(String uid) async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      bool isCharging =
          state == BatteryState.charging || state == BatteryState.full;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'batteryLevel': level,
        'isCharging': isCharging,
        'lastBatteryUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log("Error al actualizar bateria: $e");
    }
  }
}
