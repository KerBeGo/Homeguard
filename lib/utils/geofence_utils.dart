import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceUtils {
  /// Verifica si un punto (lat, lng) está dentro de un polígono.
  /// Implementa el algoritmo de "Ray Casting".
  ///
  /// [point]: GeoPoint con la ubicación del paciente.
  /// [polygon]: Lista de GeoPoints que definen la zona segura.
  static bool isPointInPolygon(GeoPoint point, List<GeoPoint> polygon) {
    if (polygon.isEmpty) return false;

    // Si el polígono no está cerrado, lo cerramos virtualmente
    // (el último punto debe ser igual al primero).
    // Pero en lógica de listas, simplemente iteramos.

    bool isInside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i].latitude;
      double yi = polygon[i].longitude;
      double xj = polygon[j].latitude;
      double yj = polygon[j].longitude;

      bool intersect =
          ((yi > point.longitude) != (yj > point.longitude)) &&
          (point.latitude <
              (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);

      if (intersect) isInside = !isInside;

      j = i;
    }

    return isInside;
  }
}
