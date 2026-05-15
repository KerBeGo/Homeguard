class UsuarioModel {
  final String uid; // ID único de Firebase
  final String email;
  final String nombre;
  final String rol; // "PACIENTE" o "CUIDADOR"
  final String codigoVinculacion;
  final String? fcmToken; // Opcional: Para notificaciones
  final String? telefono; // Opcional: Para alertas SMS

  // Constructor
  UsuarioModel({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.codigoVinculacion,
    this.fcmToken,
    this.telefono,
  });

  // 1. Convertir de MAPA (JSON de Firebase) a OBJETO DART
  // Esto se usa cuando LEES datos de la base de datos
  factory UsuarioModel.fromMap(Map<String, dynamic> map, String id) {
    return UsuarioModel(
      uid: id,
      email: map['email'] ?? '',
      nombre: map['nombre'] ?? '',
      rol: map['rol'] ?? 'PACIENTE',
      codigoVinculacion: map['codigoVinculacion'] ?? '',
      fcmToken: map['fcmToken'],
      telefono: map['telefono'],
    );
  }

  // 2. Convertir de OBJETO DART a MAPA (JSON para Firebase)
  // Esto se usa cuando GUARDAS datos en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'codigoVinculacion': codigoVinculacion,
      'fcmToken': fcmToken,
      'telefono': telefono,
    };
  }
}
