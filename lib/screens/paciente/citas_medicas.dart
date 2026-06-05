import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/appointment_model.dart';
import '../../services/local_notification_service.dart';
import '../../services/alert_service.dart';

class CitasMedicas extends StatefulWidget {
  const CitasMedicas({super.key});

  @override
  State<CitasMedicas> createState() => _CitasMedicasState();
}

class _CitasMedicasState extends State<CitasMedicas> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<void> _agregarCita() async {
    final TextEditingController doctorController = TextEditingController();
    final TextEditingController especialidadController = TextEditingController();
    final TextEditingController notasController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nueva Cita Médica"),
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
                  pacienteId: user.uid,
                  doctor: doctorController.text,
                  especialidad: especialidadController.text,
                  fecha: appointmentDateTime,
                  notas: notasController.text,
                );

                try {
                  // Guardar en Firestore
                  final docRef = await FirebaseFirestore.instance
                      .collection('citas')
                      .add(appointment.toMap());

                  // Programar notificación local
                  await LocalNotificationService().scheduleAppointmentNotification(
                    id: (docRef.id.hashCode.abs() % 10000000),
                    doctor: appointment.doctor,
                    especialidad: appointment.especialidad,
                    scheduledDate: appointmentDateTime,
                  );

                  // Notificar al cuidador
                  await AlertService().enviarAlerta(
                    tipo: 'cita',
                    mensaje: 'Nueva cita: ${appointment.especialidad} con ${appointment.doctor}',
                    mostrarNotificacionLocal: false,
                  );

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
      appBar: AppBar(
        title: const Text("Mis Citas Médicas"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('citas')
            .where('pacienteId', isEqualTo: user.uid)
            // .orderBy('fecha', descending: false) // Comentado para evitar errores de índice si no existe
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
            return const Center(
              child: Text("No tienes citas médicas programadas"),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final appointment = Appointment.fromFirestore(snapshot.data!.docs[index]);
              final isPast = appointment.fecha.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPast ? Colors.grey : Colors.teal,
                    child: const Icon(Icons.medical_services, color: Colors.white),
                  ),
                  title: Text(
                    "${appointment.especialidad} - ${appointment.doctor}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${appointment.fecha.day}/${appointment.fecha.month}/${appointment.fecha.year} ${appointment.fecha.hour}:${appointment.fecha.minute.toString().padLeft(2, '0')}\n${appointment.notas}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('citas')
                          .doc(appointment.id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarCita,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
