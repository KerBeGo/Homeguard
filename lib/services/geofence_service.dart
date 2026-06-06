import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';

class GeofenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'geofences';

  // 1. CÁLCULO DE DISTANCIA (Fórmula de Haversine)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000;
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // 2. VALIDACIÓN DE SOLAPAMIENTO
  bool hasOverlap(GeofenceModel newGeofence, List<GeofenceModel> existingGeofences) {
    for (var geofence in existingGeofences) {
      if (geofence.id == newGeofence.id) continue; // Ignorar a sí misma (para edición)

      double distance = calculateDistance(
        newGeofence.center.latitude,
        newGeofence.center.longitude,
        geofence.center.latitude,
        geofence.center.longitude,
      );

      // Si la distancia entre centros es menor a la suma de sus radios, hay solapamiento
      if (distance <= (newGeofence.radiusMeters + geofence.radiusMeters)) {
        return true;
      }
    }
    return false;
  }

  // 3. LÓGICA INCLUSIVA (Múltiples geocercas) con HISTÉRESIS
  bool isInsideSafeZones(GeoPoint currentLocation, List<GeofenceModel> activeGeofences, {double hysteresisMargin = 10.0}) {
    if (activeGeofences.isEmpty) return true; // Si no hay zonas, asumimos a salvo por defecto para no lanzar falsas alarmas, o puedes cambiar a false.

    for (var geofence in activeGeofences) {
      double distance = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        geofence.center.latitude,
        geofence.center.longitude,
      );

      // Aplicamos histéresis (buffer) para evitar el efecto rebote del GPS
      if (distance <= (geofence.radiusMeters + hysteresisMargin)) {
        return true; // Está a salvo en al menos una
      }
    }
    return false; // Está fuera de TODAS las zonas
  }

  // 4. CRUD EN FIRESTORE
  Future<String> saveGeofence(GeofenceModel geofence) async {
    try {
      if (geofence.id.isEmpty) {
        DocumentReference docRef = await _firestore.collection(_collection).add(geofence.toMap());
        return docRef.id;
      } else {
        await _firestore.collection(_collection).doc(geofence.id).update(geofence.toMap());
        return geofence.id;
      }
    } catch (e) {
      throw Exception('Error al guardar geocerca: $e');
    }
  }

  Stream<List<GeofenceModel>> getActiveGeofencesStream(String patientId) {
    return _firestore
        .collection(_collection)
        .where('patientId', isEqualTo: patientId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GeofenceModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> deleteGeofence(String geofenceId) async {
    await _firestore.collection(_collection).doc(geofenceId).delete();
  }

  Stream<List<GeofenceModel>> getActiveGeofences(String patientId) {
    return getActiveGeofencesStream(patientId);
  }

  Future<bool> isPointOutsideAllGeofences(String patientId, GeoPoint point) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .get();
      
      final geofences = snapshot.docs
          .map((doc) => GeofenceModel.fromMap(doc.data(), doc.id))
          .toList();
          
      if (geofences.isEmpty) return false;
      
      return !isInsideSafeZones(point, geofences);
    } catch (e) {
      throw Exception('Error al verificar geocercas: $e');
    }
  }

  Future<String> createGeofence({
    required String patientId,
    required String caregiverId,
    required GeoPoint center,
    required double radiusMeters,
    String name = 'Zona Segura',
  }) async {
    final geofence = GeofenceModel(
      id: '',
      patientId: patientId,
      caregiverId: caregiverId,
      name: name,
      center: center,
      radiusMeters: radiusMeters,
      createdAt: DateTime.now(),
      isActive: true,
    );
    return await saveGeofence(geofence);
  }
}
