import 'package:cloud_firestore/cloud_firestore.dart';

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
      // final pacienteData = pacienteDoc.data(); // Unused

      // (Opcional) Verificar si ya tiene cuidador asignado, si esa es una regla de negocio.
      // Por ahora permitimos re-vincular o tener múltiples cuidadores según tu lógica,
      // pero el código original sobrescribía 'cuidadorId'.

      // 2. Crear documento en la colección 'connections'
      // Usamos una ID combinada o auto-generada.
      await _firestore.collection('connections').add({
        'cuidadorId': uidCuidador,
        'pacienteId': pacienteDoc.id,
        'codigoUsado': codigo,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 3. Actualizar el documento del usuario (Legacy support / Optimización de lectura)
      // Mantenemos esto para que 'pacientes_of_cuidador.dart' siga funcionando
      // mientras migramos todo a usar la colección 'connections'.
      await _firestore.collection('users').doc(pacienteDoc.id).update({
        'cuidadorId': uidCuidador,
      });

      return true;
    } catch (e) {
      // Relanzamos la excepción para manejarla en la UI
      rethrow;
    }
  }
}
