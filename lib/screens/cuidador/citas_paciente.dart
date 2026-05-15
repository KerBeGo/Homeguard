import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';

class CitasPaciente extends StatelessWidget {
  final String patientId;
  final String patientName;

  const CitasPaciente({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('citas')
            .where('pacienteId', isEqualTo: patientId)
            // .orderBy('fecha', descending: false) // Comentado para evitar errores de índice
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error al cargar citas: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No hay citas programadas para $patientName",
                    style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.yellow[100],
                    child: Column(
                      children: [
                        const Text("DEBUG INFO:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Buscando en colección: 'citas'"),
                        Text("pacienteId buscado: $patientId"),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final appointment = Appointment.fromFirestore(snapshot.data!.docs[index]);
              final isPast = appointment.fecha.isBefore(DateTime.now());

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPast ? Colors.grey[300] : Colors.teal[100],
                    child: Icon(
                      Icons.medical_services,
                      color: isPast ? Colors.grey : Colors.teal,
                    ),
                  ),
                  title: Text(
                    "${appointment.especialidad} - ${appointment.doctor}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    "${appointment.fecha.day}/${appointment.fecha.month}/${appointment.fecha.year} ${appointment.fecha.hour}:${appointment.fecha.minute.toString().padLeft(2, '0')}\n${appointment.notas}",
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
