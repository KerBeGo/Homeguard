import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';

/// Servicio para gestionar geocercas en Firestore
class GeofenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'geofences';

  /// Crea una nueva geocerca en Firestore
  ///
  /// [patientId]: ID del paciente
  /// [caregiverId]: ID del cuidador que crea la geocerca
  /// [center]: Centro de la geocerca (ubicación del paciente)
  /// [radiusMeters]: Radio de la geocerca en metros
  ///
  /// Retorna el ID de la geocerca creada
  Future<String> createGeofence({
    required String patientId,
    required String caregiverId,
    required GeoPoint center,
    required double radiusMeters,
  }) async {
    try {
      // Crear el modelo de geocerca
      GeofenceModel geofence = GeofenceModel(
        id: '', // Se generará automáticamente
        patientId: patientId,
        caregiverId: caregiverId,
        center: center,
        radiusMeters: radiusMeters,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Guardar en Firestore
      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(geofence.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear geocerca: $e');
    }
  }

  /// Obtiene todas las geocercas activas de un paciente
  ///
  /// [patientId]: ID del paciente
  ///
  /// Retorna un Stream con la lista de geocercas activas
  Stream<List<GeofenceModel>> getActiveGeofences(String patientId) {
    return _firestore
        .collection(_collection)
        .where('patientId', isEqualTo: patientId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GeofenceModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Desactiva una geocerca
  ///
  /// [geofenceId]: ID de la geocerca a desactivar
  Future<void> deactivateGeofence(String geofenceId) async {
    try {
      await _firestore.collection(_collection).doc(geofenceId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Error al desactivar geocerca: $e');
    }
  }

  /// Elimina permanentemente una geocerca
  ///
  /// [geofenceId]: ID de la geocerca a eliminar
  Future<void> deleteGeofence(String geofenceId) async {
    try {
      await _firestore.collection(_collection).doc(geofenceId).delete();
    } catch (e) {
      throw Exception('Error al eliminar geocerca: $e');
    }
  }

  /// Verifica si un punto está fuera de todas las geocercas activas
  ///
  /// [patientId]: ID del paciente
  /// [point]: Punto a verificar
  ///
  /// Retorna true si el punto está fuera de todas las geocercas
  Future<bool> isPointOutsideAllGeofences(
    String patientId,
    GeoPoint point,
  ) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // No hay geocercas activas
        return false;
      }

      // Verificar si está fuera de todas las geocercas
      for (var doc in snapshot.docs) {
        GeofenceModel geofence = GeofenceModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        if (geofence.isPointInside(point)) {
          // El punto está dentro de al menos una geocerca
          return false;
        }
      }

      // El punto está fuera de todas las geocercas
      return true;
    } catch (e) {
      throw Exception('Error al verificar geocercas: $e');
    }
  }
}
