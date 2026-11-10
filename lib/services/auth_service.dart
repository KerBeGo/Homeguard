import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';
import 'dart:math';
import 'tracking_service.dart';

/// Caracteres sin ambigüedad (sin 0/O ni 1/I) para que el código se dicte fácil.
const _alfabetoCodigo = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Genera un código como "ROS-K7Q2M9": 3 letras del nombre + 6 caracteres aleatorios.
/// Antes eran 4 caracteres tomados del UID (unas 65.000 combinaciones por nombre);
/// ahora son más de mil millones, generados con un generador criptográfico.
String generarCodigoVinculacion(String nombre, {Random? random}) {
  final rnd = random ?? Random.secure();
  final letras = nombre.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  final prefijo = (letras.length >= 3 ? letras.substring(0, 3) : letras.padRight(3, 'X'));
  final sufijo = List.generate(6, (_) => _alfabetoCodigo[rnd.nextInt(_alfabetoCodigo.length)]).join();
  return '$prefijo-$sufijo';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para Registrarse
  Future<String?> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    required String rol, // "CUIDADOR" o "PACIENTE"
    String? telefono,
    int? edad,
    String? fechaNacimiento,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth (Solo email y pass)
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Generar el código de vinculación único
      // (aleatorio y difícil de adivinar: ver generarCodigoVinculacion)
      String codigoUnico = generarCodigoVinculacion(nombre);

      // 3. Crear nuestro Modelo de datos
      UsuarioModel nuevoUsuario = UsuarioModel(
        uid: userCredential.user!.uid,
        email: email,
        nombre: nombre,
        rol: rol,
        codigoVinculacion: codigoUnico,
        telefono: telefono,
        edad: edad,
        fechaNacimiento: fechaNacimiento,
      );

      // 4. Guardar en Firestore (Base de Datos)
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(nuevoUsuario.toMap());

      return null; // Null significa "Todo salió bien"
    } on FirebaseAuthException catch (e) {
      return e.message; // Devuelve el error (ej: "Email ya en uso")
    } catch (e) {
      // Si falla ALGO (ej: Firestore), borramos el usuario creado
      // para no dejar "usuarios zombis" sin datos en la BD.
      try {
        await _auth.currentUser?.delete();
      } catch (_) {
        // Ignoramos error al borrar
      }
      return "Ocurrió un error al guardar datos: $e";
    }
  }

  // Función para Iniciar Sesión (Login)
  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Todo salió bien
    } on FirebaseAuthException catch (e) {
      // Traducimos algunos errores comunes de Firebase al español
      if (e.code == 'user-not-found') return 'Usuario no encontrado.';
      if (e.code == 'wrong-password') return 'Contraseña incorrecta.';
      return e.message;
    } catch (e) {
      return "Error: $e";
    }
  }

  // Función para Salir
  Future<void> cerrarSesion() async {
    TrackingService().stopMonitoring();
    await _auth.signOut();
  }
}
