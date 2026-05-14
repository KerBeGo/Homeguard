import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/geofence_model.dart';
import '../../services/geofence_service.dart';
import '../../widgets/create_geofence_dialog.dart';

class MapaScreen extends StatefulWidget {
  final String patientId;

  const MapaScreen({super.key, required this.patientId});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  GoogleMapController? _mapController;
  final LatLng _defaultCenter = const LatLng(10.496, -66.898);
  final GeofenceService _geofenceService = GeofenceService();

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Muestra el diálogo para crear una nueva geocerca
  void _showCreateGeofenceDialog(GeoPoint patientLocation) {
    showDialog(
      context: context,
      builder: (context) => CreateGeofenceDialog(
        onCreateGeofence: (double radiusMeters) async {
          await _createGeofence(patientLocation, radiusMeters);
        },
      ),
    );
  }

  /// Crea una nueva geocerca en Firestore
  Future<void> _createGeofence(GeoPoint center, double radiusMeters) async {
    try {
      // Obtener el ID del cuidador actual
      String? caregiverId = FirebaseAuth.instance.currentUser?.uid;

      if (caregiverId == null) {
        throw Exception('No se pudo obtener el ID del cuidador');
      }

      // Crear la geocerca usando el servicio
      await _geofenceService.createGeofence(
        patientId: widget.patientId,
        caregiverId: caregiverId,
        center: center,
        radiusMeters: radiusMeters,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Geocerca creada exitosamente (${radiusMeters.toInt()}m)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al crear geocerca: $e',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .snapshots(),
      builder: (context, patientSnapshot) {
        if (patientSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        GeoPoint? patientLocation;

        // Obtener la ubicación del paciente
        if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
          var data = patientSnapshot.data!.data() as Map<String, dynamic>;
          if (data.containsKey('location')) {
            patientLocation = data['location'] as GeoPoint?;

            if (patientLocation != null) {
              final LatLng patientLatLng = LatLng(
                patientLocation.latitude,
                patientLocation.longitude,
              );

              _markers = {
                Marker(
                  markerId: MarkerId(widget.patientId),
                  position: patientLatLng,
                  infoWindow: const InfoWindow(title: 'Paciente'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
              };

              // Si el mapa ya está listo, centramos la cámara en el paciente
              if (mounted && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(patientLatLng),
                );
              }
            }
          }
        }

        if (patientLocation == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                "Aún no hay datos de ubicación de este paciente.\nEl monitoreo debe estar activo en su dispositivo.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // StreamBuilder para las geocercas activas
        return StreamBuilder<List<GeofenceModel>>(
          stream: _geofenceService.getActiveGeofences(widget.patientId),
          builder: (context, geofenceSnapshot) {
            // Crear círculos para cada geocerca
            if (geofenceSnapshot.hasData) {
              _circles = geofenceSnapshot.data!.map((geofence) {
                return Circle(
                  circleId: CircleId(geofence.id),
                  center: LatLng(
                    geofence.center.latitude,
                    geofence.center.longitude,
                  ),
                  radius: geofence.radiusMeters,
                  fillColor: Colors.lightBlueAccent.withValues(alpha: 0.2),
                  strokeColor: Colors.blue,
                  strokeWidth: 2,
                );
              }).toSet();
            }

            return Scaffold(
              body: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _markers.isNotEmpty
                      ? _markers.first.position
                      : _defaultCenter,
                  zoom: 15.0,
                ),
                markers: _markers,
                circles: _circles,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
              ),
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(bottom: 75),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    if (patientLocation != null) {
                      _showCreateGeofenceDialog(patientLocation);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'No se pudo obtener la ubicación del paciente',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.orange[700],
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Crear Geocerca'),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            );
          },
        );
      },
    );
  }
}
