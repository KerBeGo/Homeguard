import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/alerts_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> enviarAlerta({
    required String tipo,
    required String mensaje,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Obtener datos del paciente para la alerta
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final nombrePaciente = data['nombre'] ?? 'Paciente';
    final cuidadorId = data['cuidadorId'];

    if (cuidadorId == null) {
      // print("No hay cuidador vinculado para enviar la alerta");
      // En una aplicación real, podrías querer manejar esto de forma diferente
      // (ej: enviar a una lista general o notificar al paciente)
      return;
    }

    final nuevaAlerta = AlertModel(
      tipo: tipo,
      mensaje: mensaje,
      pacienteId: user.uid,
      pacienteNombre: nombrePaciente,
      cuidadorId: cuidadorId,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('alertas').add(nuevaAlerta.toMap());
  }
}
