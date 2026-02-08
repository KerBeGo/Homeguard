import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  // Esta variable controlará el mapa
  late GoogleMapController mapController;

  // Coordenadas iniciales (ejemplo: Plaza Venezuela, Caracas)
  // Puedes cambiarlas por las que quieras que salgan al abrir la app
  final LatLng _center = const LatLng(10.496, -66.898);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeGuard Monitor'),
        backgroundColor: Colors.green[700],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 15.0, // Mientras más alto el número, más cerca el zoom
        ),
        // Aquí puedes agregar marcadores luego
        markers: {
          const Marker(
            markerId: MarkerId('casa_monitoreada'),
            position: LatLng(10.496, -66.898),
            infoWindow: InfoWindow(title: 'Ubicación HomeGuard'),
          ),
        },
      ),
    );
  }
}
