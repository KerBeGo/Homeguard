class Medication {
  final String? id;
  final int notificationId;
  final String nombre;
  final String descripcion;
  final String categoria;
  final String frecuenciaTipo;
  final List<int>? diasEspecificos; // 1 = Monday, 7 = Sunday
  final List<int>? diasMes; // 1 to 31
  final int? intervaloDias;
  final int? periodoCantidad;
  final String? periodoUnidad; // 'semana', 'mes', 'año'
  final List<String> horas; // Format: "HH:mm"
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool activo;

  Medication({
    this.id,
    required this.notificationId,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.frecuenciaTipo,
    this.diasEspecificos,
    this.diasMes,
    this.intervaloDias,
    this.periodoCantidad,
    this.periodoUnidad,
    required this.horas,
    this.fechaInicio,
    this.fechaFin,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'frecuenciaTipo': frecuenciaTipo,
      'diasEspecificos': diasEspecificos,
      'diasMes': diasMes,
      'intervaloDias': intervaloDias,
      'periodoCantidad': periodoCantidad,
      'periodoUnidad': periodoUnidad,
      'horas': horas,
      'fechaInicio': fechaInicio?.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'activo': activo,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map, String docId) {
    return Medication(
      id: docId,
      notificationId: map['notificationId']?.toInt() ?? 0,
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      categoria: map['categoria'] ?? '',
      frecuenciaTipo: map['frecuenciaTipo'] ?? '',
      diasEspecificos: (map['diasEspecificos'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      diasMes: (map['diasMes'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      intervaloDias: map['intervaloDias']?.toInt(),
      periodoCantidad: map['periodoCantidad']?.toInt(),
      periodoUnidad: map['periodoUnidad'],
      horas: List<String>.from(map['horas'] ?? []),
      fechaInicio: map['fechaInicio'] != null
          ? DateTime.parse(map['fechaInicio'])
          : null,
      fechaFin: map['fechaFin'] != null
          ? DateTime.parse(map['fechaFin'])
          : null,
      activo: map['activo'] ?? true,
    );
  }

  Medication copyWith({
    String? id,
    int? notificationId,
    String? nombre,
    String? descripcion,
    String? categoria,
    String? frecuenciaTipo,
    List<int>? diasEspecificos,
    List<int>? diasMes,
    int? intervaloDias,
    int? periodoCantidad,
    String? periodoUnidad,
    List<String>? horas,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? activo,
  }) {
    return Medication(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      frecuenciaTipo: frecuenciaTipo ?? this.frecuenciaTipo,
      diasEspecificos: diasEspecificos ?? this.diasEspecificos,
      diasMes: diasMes ?? this.diasMes,
      intervaloDias: intervaloDias ?? this.intervaloDias,
      periodoCantidad: periodoCantidad ?? this.periodoCantidad,
      periodoUnidad: periodoUnidad ?? this.periodoUnidad,
      horas: horas ?? this.horas,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      activo: activo ?? this.activo,
    );
  }
}
