import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String? id;
  final String tipo; // 'caida', 'medicamento', 'zona_segura', 'sos'
  final String mensaje;
  final String pacienteId;
  final String pacienteNombre;
  final String cuidadorId;
  final DateTime timestamp;
  final bool leida;

  AlertModel({
    this.id,
    required this.tipo,
    required this.mensaje,
    required this.pacienteId,
    required this.pacienteNombre,
    required this.cuidadorId,
    required this.timestamp,
    this.leida = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'mensaje': mensaje,
      'pacienteId': pacienteId,
      'pacienteNombre': pacienteNombre,
      'cuidadorId': cuidadorId,
      'timestamp': Timestamp.fromDate(timestamp),
      'leida': leida,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, String id) {
    return AlertModel(
      id: id,
      tipo: map['tipo'] ?? '',
      mensaje: map['mensaje'] ?? '',
      pacienteId: map['pacienteId'] ?? '',
      pacienteNombre: map['pacienteNombre'] ?? '',
      cuidadorId: map['cuidadorId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      leida: map['leida'] ?? false,
    );
  }
}
