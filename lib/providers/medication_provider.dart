import 'package:flutter/material.dart';
import '../models/medication_model.dart';
import 'dart:math';

class MedicationProvider with ChangeNotifier {
  Medication? _currentMedication;

  Medication? get currentMedication => _currentMedication;

  void startNewMedication() {
    _currentMedication = Medication(
      notificationId: Random().nextInt(100000), // Random ID for notifications
      nombre: '',
      descripcion: '',
      categoria: 'Pastilla', // Default
      frecuenciaTipo: 'Diario', // Default
      horas: [],
    );
    notifyListeners();
  }

  void updateIdentidad(String nombre, String descripcion, String categoria) {
    if (_currentMedication != null) {
      _currentMedication = _currentMedication!.copyWith(
        nombre: nombre,
        descripcion: descripcion,
        categoria: categoria,
      );
      notifyListeners();
    }
  }

  void updateFrecuencia(
    String frecuenciaTipo, {
    List<int>? diasEspecificos,
    int? intervaloDias,
    int? periodoVecesMes,
  }) {
    if (_currentMedication != null) {
      // Clear specific list values based on the new type if needed, but here we just overwrite
      _currentMedication = _currentMedication!.copyWith(
        frecuenciaTipo: frecuenciaTipo,
        diasEspecificos: diasEspecificos,
        intervaloDias: intervaloDias,
        periodoVecesMes: periodoVecesMes,
      );
      notifyListeners();
    }
  }

  void updateTemporizacion(
    List<String> horas,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  ) {
    if (_currentMedication != null) {
      _currentMedication = _currentMedication!.copyWith(
        horas: horas,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      notifyListeners();
    }
  }

  void clear() {
    _currentMedication = null;
    notifyListeners();
  }
}
