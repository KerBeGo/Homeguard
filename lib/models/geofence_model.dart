import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceModel {
  final String id;
  final String patientId;
  final String caregiverId;
  final String name;
  final GeoPoint center;
  final double radiusMeters; // min 50, max 1000
  final DateTime createdAt;
  final bool isActive;

  GeofenceModel({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    this.name = 'Zona Segura',
    required this.center,
    required this.radiusMeters,
    required this.createdAt,
    this.isActive = true,
  });

  factory GeofenceModel.fromMap(Map<String, dynamic> map, String id) {
    return GeofenceModel(
      id: id,
      patientId: map['patientId'] ?? '',
      caregiverId: map['caregiverId'] ?? '',
      name: map['name'] ?? 'Zona Segura',
      center: map['center'] as GeoPoint,
      radiusMeters: (map['radiusMeters'] ?? 50.0).toDouble().clamp(50.0, 1000.0),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'caregiverId': caregiverId,
      'name': name,
      'center': center,
      'radiusMeters': radiusMeters.clamp(50.0, 1000.0),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  GeofenceModel copyWith({
    String? id,
    String? patientId,
    String? caregiverId,
    String? name,
    GeoPoint? center,
    double? radiusMeters,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      caregiverId: caregiverId ?? this.caregiverId,
      name: name ?? this.name,
      center: center ?? this.center,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  bool isPointInside(GeoPoint point) {
    const double earthRadiusMeters = 6371000;
    double dLat = (point.latitude - center.latitude) * pi / 180;
    double dLon = (point.longitude - center.longitude) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(center.latitude * pi / 180) *
            cos(point.latitude * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    double distance = earthRadiusMeters * c;
    return distance <= radiusMeters;
  }
}
