import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_model.dart';
import '../../services/medication_service.dart';
import '../../providers/medication_provider.dart';
import 'medication_wizard.dart';
import 'medication_status_view.dart';

class MedicationControlScreen extends StatelessWidget {
  final String patientId; // Requires patient ID from context/routing usually

  // Hardcoded for testing, ensure you pass it from the routing logic.
  const MedicationControlScreen({
    super.key,
    this.patientId = 'patient_test_id',
  });

  @override
  Widget build(BuildContext context) {
    final service = MedicationService();

    return Scaffold(
      appBar: AppBar(title: const Text('Control de Medicamentos')),
      body: StreamBuilder<List<Medication>>(
        stream: service.getPatientMedications(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final meds = snapshot.data ?? [];
          if (meds.isEmpty) {
            return const Center(
              child: Text('No hay medicamentos activos. \n¡Agrega uno nuevo!'),
            );
          }

          return ListView.builder(
            itemCount: meds.length,
            itemBuilder: (context, index) {
              final med = meds[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.medication)),
                title: Text(med.nombre),
                subtitle: Text(
                  '${med.frecuenciaTipo} - ${med.horas.join(', ')}',
                ),
                onTap: () {
                  if (med.id != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MedicationStatusView(
                          patientId: patientId,
                          medication: med,
                        ),
                      ),
                    );
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Soft delete logic
                    if (med.id != null) {
                      service.deactivateMedication(patientId, med.id!);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => MedicationProvider(),
                child: MedicationWizard(patientId: patientId),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
