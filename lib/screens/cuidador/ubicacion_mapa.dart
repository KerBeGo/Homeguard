import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/geofence_model.dart';
import '../../services/geofence_service.dart';
import 'create_geofence_screen.dart';

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

  void _showGeofencesList(BuildContext context, List<GeofenceModel> geofences, GeoPoint? patientLocation, String patientName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Zonas Seguras del Paciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (geofences.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No hay zonas seguras creadas.'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: geofences.length,
                    itemBuilder: (context, index) {
                      var geofence = geofences[index];
                      return ListTile(
                        leading: const Icon(Icons.security, color: Colors.green),
                        title: Text(geofence.name),
                        subtitle: Text('Radio: ${geofence.radiusMeters.toInt()}m'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.pop(context); // Cerrar bottomsheet
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateGeofenceScreen(
                                      patientId: widget.patientId,
                                      existingGeofences: geofences,
                                      initialCenter: patientLocation,
                                      patientName: patientName,
                                      geofenceToEdit: geofence,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _geofenceService.deleteGeofence(geofence.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Nueva Zona'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateGeofenceScreen(
                          patientId: widget.patientId,
                          existingGeofences: geofences,
                          initialCenter: patientLocation,
                          patientName: patientName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
        String patientName = 'Paciente';

        // Obtener la ubicación del paciente
        if (patientSnapshot.hasData && patientSnapshot.data!.exists) {
          var data = patientSnapshot.data!.data() as Map<String, dynamic>;
          if (data.containsKey('nombre')) {
            patientName = data['nombre'] ?? 'Paciente';
          }
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
                  infoWindow: InfoWindow(title: patientName),
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
                  onPressed: () => _showGeofencesList(context, geofenceSnapshot.data ?? [], patientLocation, patientName),
                  icon: const Icon(Icons.format_list_bulleted),
                  label: const Text('Gestionar Zonas'),
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
