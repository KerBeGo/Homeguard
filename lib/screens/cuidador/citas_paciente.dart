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

  Future<void> _agregarCita(BuildContext context) async {
    final TextEditingController doctorController = TextEditingController();
    final TextEditingController especialidadController = TextEditingController();
    final TextEditingController notasController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Nueva Cita para $patientName"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: doctorController,
                  decoration: const InputDecoration(labelText: "Doctor"),
                ),
                TextField(
                  controller: especialidadController,
                  decoration: const InputDecoration(labelText: "Especialidad"),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text("Fecha: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: Text("Hora: ${selectedTime.format(context)}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setState(() => selectedTime = picked);
                    }
                  },
                ),
                TextField(
                  controller: notasController,
                  decoration: const InputDecoration(labelText: "Notas (opcional)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (doctorController.text.isEmpty || especialidadController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Por favor rellena doctor y especialidad")),
                  );
                  return;
                }

                final DateTime appointmentDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final appointment = Appointment(
                  pacienteId: patientId,
                  doctor: doctorController.text,
                  especialidad: especialidadController.text,
                  fecha: appointmentDateTime,
                  notas: notasController.text,
                );

                try {
                  await FirebaseFirestore.instance
                      .collection('citas')
                      .add(appointment.toMap());

                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error al guardar cita: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }


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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _agregarCita(context),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
