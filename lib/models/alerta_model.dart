import 'package:cloud_firestore/cloud_firestore.dart';

class AlertaModel {
  final String id;
  final String tipo; // 'ambulancia' | 'incendio' | 'alerta' | 'ayuda'
  final int casaNumero;
  final String condominio;
  final String propietarioId;
  final String propietarioNombre;
  final String estado; // 'activa' | 'atendida'
  final String? atendidaPor;
  final String? atendidaPorNombre;
  final DateTime? atendidaAt;
  final DateTime creadoAt;
  final String? notas;

  AlertaModel({
    required this.id,
    required this.tipo,
    required this.casaNumero,
    required this.condominio,
    required this.propietarioId,
    required this.propietarioNombre,
    required this.estado,
    this.atendidaPor,
    this.atendidaPorNombre,
    this.atendidaAt,
    required this.creadoAt,
    this.notas,
  });

  factory AlertaModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AlertaModel(
      id: id,
      tipo: data['tipo'] ?? 'alerta',
      casaNumero: data['casaNumero'] ?? 0,
      condominio: data['condominio'] ?? '',
      propietarioId: data['propietarioId'] ?? '',
      propietarioNombre: data['propietarioNombre'] ?? '',
      estado: data['estado'] ?? 'activa',
      atendidaPor: data['atendidaPor'],
      atendidaPorNombre: data['atendidaPorNombre'],
      atendidaAt: data['atendidaAt'] != null 
          ? (data['atendidaAt'] as Timestamp).toDate() 
          : null,
      creadoAt: data['creadoAt'] != null 
          ? (data['creadoAt'] as Timestamp).toDate() 
          : DateTime.now(),
      notas: data['notas'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo,
      'casaNumero': casaNumero,
      'condominio': condominio,
      'propietarioId': propietarioId,
      'propietarioNombre': propietarioNombre,
      'estado': estado,
      'atendidaPor': atendidaPor,
      'atendidaPorNombre': atendidaPorNombre,
      'atendidaAt': atendidaAt,
      'creadoAt': creadoAt,
      'notas': notas,
    };
  }

  // Getters útiles
  bool get esActiva => estado == 'activa';
  bool get esAtendida => estado == 'atendida';

  String get tipoDisplay {
    switch (tipo) {
      case 'ambulancia':
        return '🚑 Ambulancia';
      case 'incendio':
        return '🔥 Incendio';
      case 'alerta':
        return '⚠️ Alerta';
      case 'ayuda':
        return '🆘 Ayuda en casa';
      default:
        return '⚠️ Alerta';
    }
  }

  String get tipoEmoji {
    switch (tipo) {
      case 'ambulancia':
        return '🚑';
      case 'incendio':
        return '🔥';
      case 'alerta':
        return '⚠️';
      case 'ayuda':
        return '🆘';
      default:
        return '⚠️';
    }
  }

  AlertaModel copyWith({
    String? id,
    String? tipo,
    int? casaNumero,
    String? condominio,
    String? propietarioId,
    String? propietarioNombre,
    String? estado,
    String? atendidaPor,
    String? atendidaPorNombre,
    DateTime? atendidaAt,
    DateTime? creadoAt,
    String? notas,
  }) {
    return AlertaModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      casaNumero: casaNumero ?? this.casaNumero,
      condominio: condominio ?? this.condominio,
      propietarioId: propietarioId ?? this.propietarioId,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      estado: estado ?? this.estado,
      atendidaPor: atendidaPor ?? this.atendidaPor,
      atendidaPorNombre: atendidaPorNombre ?? this.atendidaPorNombre,
      atendidaAt: atendidaAt ?? this.atendidaAt,
      creadoAt: creadoAt ?? this.creadoAt,
      notas: notas ?? this.notas,
    );
  }
}
