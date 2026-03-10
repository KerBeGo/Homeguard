import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/alert_service.dart';

class MedicationConfirmScreen extends StatelessWidget {
  final String
  patientId; // Used if we need to log it per patient in a central place
  final String medicationId;
  final String medicationName;

  const MedicationConfirmScreen({
    super.key,
    required this.patientId,
    required this.medicationId,
    required this.medicationName,
  });

  Future<void> _recordToma(BuildContext context, String status) async {
    try {
      final now = DateTime.now();
      // Date format YYYY-MM-DD
      final fecha =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final hora =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance
          .collection('pacientes')
          .doc(patientId)
          .collection('medicamentos')
          .doc(medicationId)
          .collection('historial_tomas')
          .add({
            'fecha': fecha,
            'hora_programada': hora, // Simplification
            'hora_real': hora,
            'estado': status,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registrado como: $status')));
        Navigator.pop(context); // Go back or close
      }

      // Send alert to caregiver
      final AlertService alertService = AlertService();
      final msg = status == 'tomado'
          ? 'El paciente ha registrado la toma de: $medicationName'
          : 'El paciente ha indicado que OMITIÓ la toma de: $medicationName';

      await alertService.enviarAlerta(
        tipo: 'medicamento_confirmacion',
        mensaje: msg,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar Toma')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.medication, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Es hora de tomar tu medicamento:\n$medicationName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _recordToma(context, 'tomado'),
                  icon: const Icon(Icons.check),
                  label: const Text('Ya me la tomé'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _recordToma(context, 'omitido'),
                  icon: const Icon(Icons.close),
                  label: const Text('No me la tomé'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
