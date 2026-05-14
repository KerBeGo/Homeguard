import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String? id;
  final String pacienteId;
  final String? pacienteNombre;
  final String doctor;
  final String especialidad;
  final DateTime fecha;
  final String notas;
  final bool notificado;

  Appointment({
    this.id,
    required this.pacienteId,
    this.pacienteNombre,
    required this.doctor,
    required this.especialidad,
    required this.fecha,
    this.notas = '',
    this.notificado = false,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Manejo robusto de la fecha (puede venir como Timestamp o DateTime durante la sincronización)
    DateTime fechaCita;
    if (data['fecha'] is Timestamp) {
      fechaCita = (data['fecha'] as Timestamp).toDate();
    } else if (data['fecha'] is DateTime) {
      fechaCita = data['fecha'] as DateTime;
    } else {
      fechaCita = DateTime.now(); // Fallback
    }

    return Appointment(
      id: doc.id,
      pacienteId: data['pacienteId'] ?? '',
      pacienteNombre: data['pacienteNombre'] ?? '',
      doctor: data['doctor'] ?? '',
      especialidad: data['especialidad'] ?? '',
      fecha: fechaCita,
      notas: data['notas'] ?? '',
      notificado: data['notificado'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'pacienteNombre': pacienteNombre,
      'doctor': doctor,
      'especialidad': especialidad,
      'fecha': Timestamp.fromDate(fecha),
      'notas': notas,
      'notificado': notificado,
    };
  }
}
