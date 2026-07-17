import 'package:flutter/services.dart';

/// Función pura que toma un número de teléfono, lo limpia y lo formatea estrictamente.
/// Si el número no tiene la longitud correcta (10 dígitos sin el prefijo), 
/// retorna el string original.
String formatVenezuelanPhoneNumberStrict(String input) {
  // 1. Eliminar cualquier carácter no numérico
  String clean = input.replaceAll(RegExp(r'\D'), '');

  // 2. Normalizar el prefijo (quitar '58' y '0' al inicio si existen)
  if (clean.startsWith('58')) {
    clean = clean.substring(2);
  }
  if (clean.startsWith('0')) {
    clean = clean.substring(1);
  }

  // 3. Validar que tenga exactamente 10 dígitos (3 operadora + 7 número)
  if (clean.length != 10) {
    return input; // Retornar el string original si no cumple la longitud
  }

  // 4. Retornar el formato exacto: +58 ###-#######
  String operadora = clean.substring(0, 3);
  String numero = clean.substring(3);
  
  return '+58 $operadora-$numero';
}

/// TextInputFormatter para formatear el número en tiempo real mientras el usuario escribe
/// en la interfaz gráfica (UI). Mantiene el patrón +58 ###-#######.
class VenezuelanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Permitir borrar libremente
    if (oldValue.text.length > newValue.text.length) {
      return newValue;
    }

    // Extraer solo dígitos de lo que el usuario ha ingresado hasta ahora
    String clean = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Normalizar prefijos
    if (clean.startsWith('58')) {
      clean = clean.substring(2);
    }
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    // Si borró todo, dejamos el campo vacío
    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Construir el string formateado progresivamente
    String formatted = '+58 ';
    for (int i = 0; i < clean.length; i++) {
      if (i == 3) {
        formatted += '-';
      }
      // Limitar a los 10 dígitos necesarios (operadora + número)
      if (i < 10) {
        formatted += clean[i];
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
