import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';

class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Since we also need patient ID, the app might be storing it somewhere
  // For this generic service, we require the patientId.
  Future<void> saveMedication(String pacienteId, Medication medication) async {
    try {
      final docRef = _firestore
          .collection('pacientes')
          .doc(pacienteId)
          .collection('medicamentos')
          .doc(); // Auto ID

      final data = medication.toMap();
      await docRef.set(data);
    } catch (e) {
      throw Exception('Error saving medication: $e');
    }
  }

  Stream<List<Medication>> getPatientMedications(String pacienteId) {
    return _firestore
        .collection('pacientes')
        .doc(pacienteId)
        .collection('medicamentos')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Medication.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<Medication>> getPatientMedicationsFuture(String pacienteId) async {
    final querySnapshot = await _firestore
        .collection('pacientes')
        .doc(pacienteId)
        .collection('medicamentos')
        .where('activo', isEqualTo: true)
        .get();

    return querySnapshot.docs
        .map((doc) => Medication.fromMap(doc.data(), doc.id))
        .toList();
  }


  // Soft delete / deactivate
  Future<void> deactivateMedication(
    String pacienteId,
    String medicationId,
  ) async {
    try {
      await _firestore
          .collection('pacientes')
          .doc(pacienteId)
          .collection('medicamentos')
          .doc(medicationId)
          .update({'activo': false});
    } catch (e) {
      throw Exception('Error deactivating medication: $e');
    }
  }
}
