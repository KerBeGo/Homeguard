import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/geofence_model.dart';
import '../../services/geofence_service.dart';
import '../../widgets/geofence_map_selector.dart';

class CreateGeofenceScreen extends StatefulWidget {
  final String patientId;
  final List<GeofenceModel> existingGeofences;
  final GeoPoint? initialCenter;
  final String? patientName;
  final GeofenceModel? geofenceToEdit;

  const CreateGeofenceScreen({
    Key? key,
    required this.patientId,
    required this.existingGeofences,
    this.initialCenter,
    this.patientName,
    this.geofenceToEdit,
  }) : super(key: key);

  @override
  State<CreateGeofenceScreen> createState() => _CreateGeofenceScreenState();
}

class _CreateGeofenceScreenState extends State<CreateGeofenceScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  late TextEditingController _nameController;
  GeoPoint? _selectedCenter;
  double _selectedRadius = 100.0;
  bool _hasOverlap = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.geofenceToEdit?.name ?? 'Zona Segura');
    if (widget.geofenceToEdit != null) {
      _selectedCenter = widget.geofenceToEdit!.center;
      _selectedRadius = widget.geofenceToEdit!.radiusMeters;
    }
  }

  void _onSelectionChanged(GeoPoint center, double radius, bool hasOverlap) {
    setState(() {
      _selectedCenter = center;
      _selectedRadius = radius;
      _hasOverlap = hasOverlap;
    });
  }

  Future<void> _saveGeofence() async {
    if (_hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes guardar zonas que se superpongan.')),
      );
      return;
    }

    if (_selectedCenter == null) return;

    setState(() { _isSaving = true; });

    try {
      String? caregiverId = FirebaseAuth.instance.currentUser?.uid;
      GeofenceModel geofence = GeofenceModel(
        id: widget.geofenceToEdit?.id ?? '', // id original si estamos editando
        patientId: widget.patientId,
        caregiverId: caregiverId ?? '',
        name: _nameController.text.isNotEmpty ? _nameController.text : 'Zona Segura',
        center: _selectedCenter!,
        radiusMeters: _selectedRadius,
        createdAt: widget.geofenceToEdit?.createdAt ?? DateTime.now(),
        isActive: true,
      );

      await _geofenceService.saveGeofence(geofence);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geocerca creada exitosamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() { _isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.geofenceToEdit == null ? 'Nueva Geocerca' : 'Editar Geocerca'),
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Icon(Icons.check),
            onPressed: (_isSaving || _hasOverlap) ? null : _saveGeofence,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Zona (ej. Casa, Parque)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_location),
              ),
            ),
          ),
          Expanded(
            child: GeofenceMapSelector(
              existingGeofences: widget.existingGeofences,
              geofenceToEdit: widget.geofenceToEdit,
              initialCenter: widget.initialCenter,
              patientName: widget.patientName,
              onSelectionChanged: _onSelectionChanged,
            ),
          ),
        ],
      ),
    );
  }
}
