// Pruebas unitarias de funciones puras (no requieren Firebase).
// Ejecutar: flutter test
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:homeguard/services/auth_service.dart';
import 'package:homeguard/utils/phone_formatter.dart';

void main() {
  group('Código de vinculación', () {
    test('tiene 3 letras del nombre, un guion y 6 caracteres', () {
      final codigo = generarCodigoVinculacion('Rosa Pérez');
      expect(codigo, matches(RegExp(r'^ROS-[A-HJ-NP-Z2-9]{6}$')));
    });

    test('ignora acentos y espacios, y rellena nombres cortos', () {
      expect(generarCodigoVinculacion('Ána', random: Random(1)), startsWith('NAX-'));
      expect(generarCodigoVinculacion('Li', random: Random(1)), startsWith('LIX-'));
    });

    test('no repite códigos en 1.000 generaciones', () {
      final codigos = {for (var i = 0; i < 1000; i++) generarCodigoVinculacion('Juan')};
      expect(codigos.length, 1000);
    });
  });

  group('Teléfono venezolano', () {
    test('normaliza distintos formatos al estándar +58', () {
      expect(formatVenezuelanPhoneNumberStrict('0412-1234567'), '+58 412-1234567');
      expect(formatVenezuelanPhoneNumberStrict('+58 414 765 4321'), '+58 414-7654321');
    });

    test('devuelve el texto original si la longitud no es válida', () {
      expect(formatVenezuelanPhoneNumberStrict('12345'), '12345');
    });
  });
}
