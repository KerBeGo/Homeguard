import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para Registrarse
  Future<String?> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    required String rol, // "CUIDADOR" o "PACIENTE"
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth (Solo email y pass)
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2. Generar el código de vinculación único
      // (Usamos parte del ID único para asegurar que no se repita)
      String codigoUnico =
          "${nombre.substring(0, 3).toUpperCase()}-${userCredential.user!.uid.substring(0, 4).toUpperCase()}";

      // 3. Crear nuestro Modelo de datos
      UsuarioModel nuevoUsuario = UsuarioModel(
        uid: userCredential.user!.uid,
        email: email,
        nombre: nombre,
        rol: rol,
        codigoVinculacion: codigoUnico,
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
      return "Ocurrió un error desconocido: $e";
    }
  }

  // Función para Salir
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }
}
