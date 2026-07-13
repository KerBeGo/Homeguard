import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Vincula un paciente a un cuidador usando el código único del paciente.
  ///
  /// Retorna `true` si la vinculación fue exitosa.
  /// Lanza una excepción con un mensaje descriptivo si falla.
  Future<bool> vincularPaciente(String codigo, String uidCuidador) async {
    try {
      // 1. Buscar al paciente con ese código
      final querySnapshot = await _firestore
          .collection('users')
          .where('codigoVinculacion', isEqualTo: codigo)
          .where('rol', isEqualTo: 'PACIENTE') // Aseguramos que sea paciente
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("No se encontró ningún paciente con ese código.");
      }

      final pacienteDoc = querySnapshot.docs.first;

      // 2. Verificar duplicados
      final duplicateCheck = await _firestore.collection('connections')
          .where('cuidadorId', isEqualTo: uidCuidador)
          .where('pacienteId', isEqualTo: pacienteDoc.id)
          .get();
      
      if (duplicateCheck.docs.isNotEmpty) {
        throw Exception("Ya estás vinculado con este paciente.");
      }

      // 3. Verificar límite de pacientes por cuidador (Máximo 5)
      final caregiverPatients = await _firestore.collection('connections')
          .where('cuidadorId', isEqualTo: uidCuidador)
          .get();
          
      if (caregiverPatients.docs.length >= 5) {
        throw Exception("Has alcanzado el límite máximo de 5 pacientes vinculados.");
      }

      // 4. Verificar límite de cuidadores por paciente (Máximo 5)
      final patientCaregivers = await _firestore.collection('connections')
          .where('pacienteId', isEqualTo: pacienteDoc.id)
          .get();
          
      if (patientCaregivers.docs.length >= 5) {
        throw Exception("Este paciente ya tiene el máximo de 5 cuidadores asignados.");
      }

      // 5. Crear documento en la colección 'connections'
      // Usamos una ID combinada o auto-generada.
      await _firestore.collection('connections').add({
        'cuidadorId': uidCuidador,
        'pacienteId': pacienteDoc.id,
        'codigoUsado': codigo,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 6. Obtener el teléfono del cuidador para emergencias offline
      final cuidadorDoc = await _firestore.collection('users').doc(uidCuidador).get();
      final cuidadorTelefono = cuidadorDoc.exists ? (cuidadorDoc.data() as Map<String, dynamic>)['telefono'] : null;

      // 7. Actualizar el documento del usuario (Legacy support / Optimización de lectura)
      await _firestore.collection('users').doc(pacienteDoc.id).update({
        'cuidadorId': uidCuidador,
        'cuidadorTelefono': cuidadorTelefono,
      });

      // 8. Guardar localmente para el ShutdownReceiver nativo
      if (cuidadorTelefono != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cuidadorTelefono', cuidadorTelefono);
      }

      return true;
    } catch (e) {
      // Relanzamos la excepción para manejarla en la UI
      rethrow;
    }
  }

  /// Desvincula a un paciente de su cuidador.
  Future<void> desvincularPaciente(String pacienteId, String cuidadorId) async {
    try {
      // 1. Eliminar la conexión en la colección 'connections'
      final connections = await _firestore
          .collection('connections')
          .where('pacienteId', isEqualTo: pacienteId)
          .where('cuidadorId', isEqualTo: cuidadorId)
          .get();

      for (var doc in connections.docs) {
        await doc.reference.delete();
      }

      // 2. Limpiar los campos en el documento del paciente
      await _firestore.collection('users').doc(pacienteId).update({
        'cuidadorId': FieldValue.delete(),
        'cuidadorTelefono': FieldValue.delete(),
      });

      // 3. Limpiar localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cuidadorTelefono');
      await prefs.remove('cuidadorId');
      await prefs.remove('pacienteNombre');
    } catch (e) {
      rethrow;
    }
  }
}
