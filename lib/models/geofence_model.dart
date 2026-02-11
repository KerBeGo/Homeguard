import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para una Geocerca circular
class GeofenceModel {
  final String id;
  final String patientId;
  final String caregiverId;
  final GeoPoint center; // Centro de la geocerca (lat, lng)
  final double radiusMeters; // Radio en metros
  final DateTime createdAt;
  final bool isActive; // Si la geocerca está activa o no

  // Constructor
  GeofenceModel({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    required this.center,
    required this.radiusMeters,
    required this.createdAt,
    this.isActive = true,
  });

  /// Convertir de MAPA (JSON de Firebase) a OBJETO DART
  /// Esto se usa cuando LEES datos de la base de datos
  factory GeofenceModel.fromMap(Map<String, dynamic> map, String id) {
    return GeofenceModel(
      id: id,
      patientId: map['patientId'] ?? '',
      caregiverId: map['caregiverId'] ?? '',
      center: map['center'] as GeoPoint,
      radiusMeters: (map['radiusMeters'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  /// Convertir de OBJETO DART a MAPA (JSON para Firebase)
  /// Esto se usa cuando GUARDAS datos en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'caregiverId': caregiverId,
      'center': center,
      'radiusMeters': radiusMeters,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  /// Verifica si un punto está dentro de la geocerca circular
  /// Usa la fórmula de Haversine para calcular la distancia
  bool isPointInside(GeoPoint point) {
    double distance = _calculateDistance(
      center.latitude,
      center.longitude,
      point.latitude,
      point.longitude,
    );
    return distance <= radiusMeters;
  }

  /// Calcula la distancia entre dos puntos geográficos en metros
  /// Fórmula de Haversine
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000; // Radio de la Tierra en metros

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * asin(sqrt(a));

    return earthRadiusMeters * c;
  }

  /// Convierte grados a radianes
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
