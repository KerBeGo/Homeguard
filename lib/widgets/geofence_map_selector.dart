import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';
import '../services/geofence_service.dart';

class GeofenceMapSelector extends StatefulWidget {
  final List<GeofenceModel> existingGeofences;
  final GeofenceModel? geofenceToEdit; // null si es nueva
  final GeoPoint? initialCenter;
  final String? patientName;
  final Function(GeoPoint center, double radius, bool hasOverlap) onSelectionChanged;

  const GeofenceMapSelector({
    super.key,
    required this.existingGeofences,
    this.geofenceToEdit,
    this.initialCenter,
    this.patientName,
    required this.onSelectionChanged,
  });

  @override
  State<GeofenceMapSelector> createState() => _GeofenceMapSelectorState();
}

class _GeofenceMapSelectorState extends State<GeofenceMapSelector> {

  late LatLng _currentCenter;
  late double _currentRadius;
  bool _hasOverlap = false;
  final GeofenceService _geofenceService = GeofenceService();

  @override
  void initState() {
    super.initState();
    if (widget.geofenceToEdit != null) {
      _currentCenter = LatLng(
        widget.geofenceToEdit!.center.latitude,
        widget.geofenceToEdit!.center.longitude,
      );
      _currentRadius = widget.geofenceToEdit!.radiusMeters;
    } else if (widget.initialCenter != null) {
      _currentCenter = LatLng(widget.initialCenter!.latitude, widget.initialCenter!.longitude);
      _currentRadius = 100.0;
    } else {
      // Default center
      _currentCenter = const LatLng(10.4806, -66.9036); 
      _currentRadius = 100.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkOverlap();
      }
    });
  }

  void _checkOverlap() {
    GeofenceModel tempModel = GeofenceModel(
      id: widget.geofenceToEdit?.id ?? '', // id vacío si es nuevo, así no se auto-excluye de la validación
      patientId: '',
      caregiverId: '',
      center: GeoPoint(_currentCenter.latitude, _currentCenter.longitude),
      radiusMeters: _currentRadius,
      createdAt: DateTime.now(),
    );

    bool overlap = _geofenceService.hasOverlap(tempModel, widget.existingGeofences);
    if (_hasOverlap != overlap) {
      setState(() {
        _hasOverlap = overlap;
      });
    }
    
    widget.onSelectionChanged(tempModel.center, _currentRadius, overlap);
  }

  @override
  Widget build(BuildContext context) {
    Set<Circle> circles = {};

    // Dibujar las geocercas existentes
    for (var geofence in widget.existingGeofences) {
      // Si estamos editando, no pintamos la original para no causar confusión
      if (widget.geofenceToEdit?.id != geofence.id) {
        circles.add(
          Circle(
            circleId: CircleId(geofence.id),
            center: LatLng(geofence.center.latitude, geofence.center.longitude),
            radius: geofence.radiusMeters,
            fillColor: Colors.grey.withValues(alpha: 0.3),
            strokeColor: Colors.grey,
            strokeWidth: 2,
          ),
        );
      }
    }

    // Dibujar la geocerca dinámica que se está editando o creando
    circles.add(
      Circle(
        circleId: const CircleId('current_selection'),
        center: _currentCenter,
        radius: _currentRadius,
        fillColor: _hasOverlap ? Colors.red.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
        strokeColor: _hasOverlap ? Colors.red : Colors.green,
        strokeWidth: 2,
      ),
    );

    // Marcador del paciente
    Set<Marker> markers = {};
    if (widget.initialCenter != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('patient_location'),
          position: LatLng(widget.initialCenter!.latitude, widget.initialCenter!.longitude),
          infoWindow: InfoWindow(title: widget.patientName ?? 'Ubicación del Paciente'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentCenter,
                  zoom: 15.0,
                ),

                onCameraMove: (position) {
                  setState(() {
                    _currentCenter = position.target;
                  });
                  _checkOverlap();
                },
                circles: circles,
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
              // Mira estática en el centro
              const Icon(
                Icons.add_location_alt,
                size: 40.0,
                color: Colors.black87,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radio de la zona: ${_currentRadius.toInt()} m',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Slider(
                value: _currentRadius,
                min: 50.0,
                max: 1000.0, // Límites solicitados por el usuario
                divisions: 95, // Pasos de 10 metros
                label: '${_currentRadius.toInt()} m',
                activeColor: _hasOverlap ? Colors.red : Colors.green,
                onChanged: (value) {
                  setState(() {
                    _currentRadius = value;
                  });
                  _checkOverlap();
                },
              ),
              if (_hasOverlap)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '¡Error! La zona se superpone con otra existente. Sepárelas o ajuste el radio.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        )
      ],
    );
  }
}
