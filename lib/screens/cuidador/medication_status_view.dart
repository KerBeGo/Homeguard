import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/medication_model.dart';

class MedicationStatusView extends StatelessWidget {
  final String patientId;
  final Medication medication;

  const MedicationStatusView({
    super.key,
    required this.patientId,
    required this.medication,
  });

  @override
  Widget build(BuildContext context) {
    // Only show today's history by default
    final now = DateTime.now();
    final fechaHoy =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text('Historial: ${medication.nombre}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tomas del día ($fechaHoy)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pacientes')
                  .doc(patientId)
                  .collection('medicamentos')
                  .doc(medication.id)
                  .collection('historial_tomas')
                  .where('fecha', isEqualTo: fechaHoy)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final tomas = snapshot.data?.docs ?? [];

                if (tomas.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay registros de tomas el día de hoy.'),
                  );
                }

                return ListView.builder(
                  itemCount: tomas.length,
                  itemBuilder: (context, index) {
                    final data = tomas[index].data() as Map<String, dynamic>;
                    final estado = data['estado'] as String?;
                    final horaReal = data['hora_real'] as String?;

                    // Determine icon and color based on status
                    IconData icon = Icons.help_outline;
                    Color color = Colors.grey;

                    if (estado == 'tomado') {
                      icon = Icons.check_circle;
                      color = Colors.green;
                    } else if (estado == 'omitido') {
                      icon = Icons.cancel;
                      color = Colors.red;
                    }

                    return ListTile(
                      leading: Icon(icon, color: color, size: 40),
                      title: Text('Estado: $estado'),
                      subtitle: Text(
                        'Hora reportada: ${horaReal ?? 'Desconocida'}',
                      ),
                      // Convert timestamp to time display if available
                      trailing: _buildTimeText(data['timestamp']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeText(dynamic timestamp) {
    if (timestamp == null) return const SizedBox();
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      // Basic formatting, could bring in intl for better
      return Text(
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      );
    }
    return const SizedBox();
  }
}
