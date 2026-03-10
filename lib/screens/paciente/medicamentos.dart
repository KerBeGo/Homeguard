import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/medication_service.dart';
import '../../models/medication_model.dart';
import 'medication_confirm_screen.dart';

class Medicamentos extends StatelessWidget {
  const Medicamentos({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Error: No usuario logueado")),
      );
    }

    final patientId = user.uid;
    final MedicationService medicationService = MedicationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Medicamentos"),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Medication>>(
        stream: medicationService.getPatientMedications(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: \${snapshot.error}"));
          }
          final medications = snapshot.data ?? [];

          if (medications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medication, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    "No hay medicamentos",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Tu cuidador aún no te ha asignado medicamentos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: medications.length,
            itemBuilder: (context, index) {
              final med = medications[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: const Icon(Icons.medication, color: Colors.blue),
                  ),
                  title: Text(
                    med.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${med.categoria} • ${med.frecuenciaTipo}"),
                      const SizedBox(height: 4),
                      Text(
                        "Horas: ${med.horas.join(', ')}",
                        style: const TextStyle(color: Colors.black87),
                      ),
                      if (med.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Notas: ${med.descripcion}",
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    tooltip: 'Registrar toma',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationConfirmScreen(
                            patientId: patientId,
                            medicationId: med.id ?? '',
                            medicationName: med.nombre,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
