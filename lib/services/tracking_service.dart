import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geocoding/geocoding.dart';
import '../models/geofence_model.dart';
import 'alert_service.dart';
import 'geofence_service.dart';
import 'sensor_service.dart';
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
  List<GeofenceModel> _localGeofences = []; // Cache local de geocercas

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
    
    // Iniciar monitoreo de sensores (IA Local para caídas)
    SensorService().startMonitoring();

    // Cargar geocercas localmente para uso offline
    _geofenceService.getActiveGeofences(user.uid).first.then((list) {
      _localGeofences = list;
    });

    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // Notificar cualquier pequeño cambio
        forceLocationManager: false, // Usar Google Play Services para mejor precisión
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Monitoreando ubicación con alta precisión.",
          notificationTitle: "Homeguard Activado",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
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
    
    // Detener sensores
    SensorService().stopMonitoring();
  }

  void _notifyListeners(String status, bool tracking) {
    if (onStatusChange != null) {
      onStatusChange!(status, tracking);
    }
  }

  Future<void> _updateLocation(String uid, Position position) async {
    final currentPoint = GeoPoint(position.latitude, position.longitude);
    
    // 0. Resolver dirección (Geocodificación inversa)
    String address = "Cargando dirección...";
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> parts = [];
        
        // Priorizamos la Calle y el Número (Dirección Postal)
        String? calle = place.thoroughfare;
        String? numero = place.subThoroughfare;
        String? sector = place.subLocality;
        String? ciudad = place.locality;

        if (calle != null && calle.isNotEmpty) {
          if (numero != null && numero.isNotEmpty && numero != calle) {
            parts.add("$calle $numero");
          } else {
            parts.add(calle);
          }
        } else if (place.name != null && place.name!.isNotEmpty) {
          // Si no hay calle, usamos el nombre como último recurso
          parts.add(place.name!);
        }

        if (sector != null && sector.isNotEmpty) parts.add(sector);
        if (ciudad != null && ciudad.isNotEmpty) parts.add(ciudad);
        
        address = parts.join(", ");
      }
    } catch (e) {
      address = "Dirección no disponible";
    }

    // 1. Intentar actualizar en la nube (Requiere internet)
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'location': currentPoint,
        'address': address,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      log("Offline: No se pudo subir ubicación a la nube, continuando monitoreo local.");
    }

    // 2. Verificación de Geocerca (LOCAL / OFFLINE)
    // Primero intentamos con el cache local (rápido y funciona sin internet)
    bool isOutside = false;
    
    if (_localGeofences.isNotEmpty) {
      // Uso de IA Local / Lógica local para verificar zona segura
      isOutside = _localGeofences.every((g) => !g.isPointInside(currentPoint));
    } else {
      // Fallback a consulta Firestore si el cache está vacío
      try {
        isOutside = await _geofenceService.isPointOutsideAllGeofences(uid, currentPoint);
      } catch (e) {
        log("Error en verificación offline de geocerca: $e");
      }
    }

    if (isOutside) {
      if (_lastGeofenceAlertTime == null ||
          DateTime.now().difference(_lastGeofenceAlertTime!) >
              const Duration(minutes: 30)) {
        _lastGeofenceAlertTime = DateTime.now();
        
        // La alerta se intenta enviar a la nube, si no hay internet se queda en la cola de Firestore (si está habilitado offline)
        // o fallará, pero al menos la app "sabe" que está fuera.
        await _alertService.enviarAlerta(
          tipo: "zona_segura",
          mensaje: "Alerta Local: El paciente ha salido de la zona segura.",
        );
      }
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
