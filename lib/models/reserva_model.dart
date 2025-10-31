import 'package:cloud_firestore/cloud_firestore.dart';

class ReservaModel {
  final String id;
  final String condominioId;
  final String areaId;
  final String areaNombre;
  final int casaNumero;
  final String userId;
  final String userName;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado; // 'pendiente', 'aprobada', 'rechazada', 'cancelada'
  final String? motivo;
  final String? adminNotas;
  final DateTime creadoAt;
  final DateTime? actualizadoAt;
  
  ReservaModel({
    required this.id,
    required this.condominioId,
    required this.areaId,
    required this.areaNombre,
    required this.casaNumero,
    required this.userId,
    required this.userName,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    this.motivo,
    this.adminNotas,
    required this.creadoAt,
    this.actualizadoAt,
  });
  
  factory ReservaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReservaModel(
      id: doc.id,
      condominioId: data['condominioId'] ?? '',
      areaId: data['areaId'] ?? '',
      areaNombre: data['areaNombre'] ?? '',
      casaNumero: data['casaNumero'] ?? 0,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      fechaInicio: (data['fechaInicio'] as Timestamp).toDate(),
      fechaFin: (data['fechaFin'] as Timestamp).toDate(),
      estado: data['estado'] ?? 'pendiente',
      motivo: data['motivo'],
      adminNotas: data['adminNotas'],
      creadoAt: (data['creadoAt'] as Timestamp).toDate(),
      actualizadoAt: data['actualizadoAt'] != null 
          ? (data['actualizadoAt'] as Timestamp).toDate() 
          : null,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'condominioId': condominioId,
      'areaId': areaId,
      'areaNombre': areaNombre,
      'casaNumero': casaNumero,
      'userId': userId,
      'userName': userName,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
      'estado': estado,
      'motivo': motivo,
      'adminNotas': adminNotas,
      'creadoAt': Timestamp.fromDate(creadoAt),
      'actualizadoAt': actualizadoAt != null 
          ? Timestamp.fromDate(actualizadoAt!) 
          : null,
    };
  }
  
  ReservaModel copyWith({
    String? id,
    String? condominioId,
    String? areaId,
    String? areaNombre,
    int? casaNumero,
    String? userId,
    String? userName,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? estado,
    String? motivo,
    String? adminNotas,
    DateTime? creadoAt,
    DateTime? actualizadoAt,
  }) {
    return ReservaModel(
      id: id ?? this.id,
      condominioId: condominioId ?? this.condominioId,
      areaId: areaId ?? this.areaId,
      areaNombre: areaNombre ?? this.areaNombre,
      casaNumero: casaNumero ?? this.casaNumero,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      estado: estado ?? this.estado,
      motivo: motivo ?? this.motivo,
      adminNotas: adminNotas ?? this.adminNotas,
      creadoAt: creadoAt ?? this.creadoAt,
      actualizadoAt: actualizadoAt ?? this.actualizadoAt,
    );
  }
  
  // Getters útiles
  bool get isPendiente => estado == 'pendiente';
  bool get isAprobada => estado == 'aprobada';
  bool get isRechazada => estado == 'rechazada';
  bool get isCancelada => estado == 'cancelada';
  
  bool get isActiva => isAprobada && DateTime.now().isBefore(fechaFin);
  bool get isPasada => DateTime.now().isAfter(fechaFin);
  bool get isFutura => DateTime.now().isBefore(fechaInicio);
  
  String get duracionFormateada {
    final duracion = fechaFin.difference(fechaInicio);
    if (duracion.inDays > 0) {
      return '${duracion.inDays} día${duracion.inDays > 1 ? 's' : ''}';
    } else if (duracion.inHours > 0) {
      return '${duracion.inHours} hora${duracion.inHours > 1 ? 's' : ''}';
    } else {
      return '${duracion.inMinutes} minutos';
    }
  }
  
  String get fechaFormateada {
    final dia = fechaInicio.day.toString().padLeft(2, '0');
    final mes = fechaInicio.month.toString().padLeft(2, '0');
    final anio = fechaInicio.year;
    final horaInicio = '${fechaInicio.hour.toString().padLeft(2, '0')}:${fechaInicio.minute.toString().padLeft(2, '0')}';
    final horaFin = '${fechaFin.hour.toString().padLeft(2, '0')}:${fechaFin.minute.toString().padLeft(2, '0')}';
    
    return '$dia/$mes/$anio de $horaInicio a $horaFin';
  }
}

class AreaComunModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String horarioInicio;
  final String horarioFin;
  final int capacidadMaxima;
  final bool requiereAprobacion;
  final bool activa;
  final String? imagenUrl;
  final List<String> normas;
  
  AreaComunModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.horarioInicio,
    required this.horarioFin,
    required this.capacidadMaxima,
    required this.requiereAprobacion,
    required this.activa,
    this.imagenUrl,
    required this.normas,
  });
  
  factory AreaComunModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AreaComunModel(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      horarioInicio: data['horarioInicio'] ?? '09:00',
      horarioFin: data['horarioFin'] ?? '22:00',
      capacidadMaxima: data['capacidadMaxima'] ?? 50,
      requiereAprobacion: data['requiereAprobacion'] ?? true,
      activa: data['activa'] ?? true,
      imagenUrl: data['imagenUrl'],
      normas: List<String>.from(data['normas'] ?? []),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'horarioInicio': horarioInicio,
      'horarioFin': horarioFin,
      'capacidadMaxima': capacidadMaxima,
      'requiereAprobacion': requiereAprobacion,
      'activa': activa,
      'imagenUrl': imagenUrl,
      'normas': normas,
    };
  }
}
