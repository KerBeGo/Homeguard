import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapaScreen extends StatefulWidget {
  final String patientId;

  const MapaScreen({super.key, required this.patientId});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  late GoogleMapController mapController;
  final LatLng _defaultCenter = const LatLng(10.496, -66.898);
  Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          if (data.containsKey('location')) {
            GeoPoint? location = data['location'] as GeoPoint?;
            if (location != null) {
              _markers = {
                Marker(
                  markerId: MarkerId(widget.patientId),
                  position: LatLng(location.latitude, location.longitude),
                  infoWindow: const InfoWindow(title: 'Paciente'),
                ),
              };

              // Move camera if mapController is ready?
              // Doing this in build is not ideal, but for now we just show the map.
              // The user can move it manually.
            }
          }
        }

        return GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _markers.isNotEmpty
                ? _markers.first.position
                : _defaultCenter,
            zoom: 15.0,
          ),
          markers: _markers,
        );
      },
    );
  }
}
