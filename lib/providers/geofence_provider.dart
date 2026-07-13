import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';
import '../services/geofence_service.dart';
import '../services/alert_service.dart' hide debugPrint;
import '../services/tracking_service.dart';

class GeofenceProvider with ChangeNotifier {
  final GeofenceService _geofenceService = GeofenceService();
  final AlertService _alertService = AlertService();

  List<GeofenceModel> _activeGeofences = [];
  List<GeofenceModel> get activeGeofences => _activeGeofences;

  bool _isSafe = true;
  bool get isSafe => _isSafe;

  StreamSubscription<List<GeofenceModel>>? _geofenceSubscription;
  Timer? _debounceTimer;

  bool _isInitialized = false;

  void init(String patientId) {
    if (_isInitialized) return;
    _isInitialized = true;

    // Suscribirse a los cambios de las geocercas en Firestore
    _geofenceSubscription = _geofenceService
        .getActiveGeofencesStream(patientId)
        .listen((geofences) {
          _activeGeofences = geofences;
          notifyListeners();
          _checkCurrentLocation();
        });

    // En lugar de iniciar un Geolocator stream paralelo y generar conflictos
    // con la notificación persistente, nos enganchamos a TrackingService.
    TrackingService().onLocationUpdate = (Position position) {
      _processLocationUpdate(position);
    };
  }

  void _processLocationUpdate(Position position) {
    if (_activeGeofences.isEmpty) {
      // Si no hay zonas configuradas, decidimos el estado por defecto (a salvo)
      if (!_isSafe) {
        _isSafe = true;
        notifyListeners();
      }
      return;
    }

    GeoPoint currentGeoPoint = GeoPoint(position.latitude, position.longitude);

    // Verificamos si está dentro usando histéresis
    bool currentlySafe = _geofenceService.isInsideSafeZones(
      currentGeoPoint,
      _activeGeofences,
      hysteresisMargin: 10.0, // 10 metros de buffer
    );

    if (currentlySafe) {
      if (!_isSafe) {
        _isSafe = true;
        notifyListeners();
      }
      // Se cancela cualquier alerta de salida pendiente
      _debounceTimer?.cancel();
    } else {
      // Salió de todas las zonas
      if (_isSafe) {
        _isSafe = false;
        notifyListeners();

        // Iniciar timer de debounce (15 segundos) para filtro de rebote
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 15), () {
          _triggerGeofenceAlert();
        });
      }
    }
  }

  Future<void> _checkCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _processLocationUpdate(position);
    } catch (e) {
      debugPrint('Error getting location for Geofence check: $e');
    }
  }

  void _triggerGeofenceAlert() {
    // AlertService ya se encarga de usar SMS como fallback en caso de no tener internet
    _alertService.enviarAlerta(
      tipo: 'ZONA SEGURA',
      mensaje: 'El paciente ha salido de todas sus zonas seguras asignadas.',
      mostrarNotificacionLocal: true,
    );
  }

  @override
  void dispose() {
    _geofenceSubscription?.cancel();
    _debounceTimer?.cancel();
    TrackingService().onLocationUpdate = null;
    super.dispose();
  }
}
