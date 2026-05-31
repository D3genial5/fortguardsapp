import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionModel {
  final String id;
  final String condominio;
  final int casaNumero;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool visto;
  final String tipo; // 'privada' o 'condominio'
  final String? prioridad; // 'baja', 'media', 'alta', 'urgente'

  NotificacionModel({
    required this.id,
    required this.condominio,
    required this.casaNumero,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.visto,
    required this.tipo,
    this.prioridad,
  });

  factory NotificacionModel.fromDoc(String id, Map<String, dynamic> data) {
    return NotificacionModel(
      id: id,
      condominio: (data['condominio'] as String?) ?? '',
      casaNumero: (data['casaNumero'] as num?)?.toInt() ?? 0,
      titulo: (data['titulo'] as String?) ?? '',
      mensaje: (data['mensaje'] as String?) ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      visto: (data['visto'] as bool?) ?? false,
      tipo: (data['tipo'] as String?) ?? 'privada',
      prioridad: data['prioridad'],
    );
  }

  Map<String, dynamic> toMap() => {
        'condominio': condominio,
        'casaNumero': casaNumero,
        'titulo': titulo,
        'mensaje': mensaje,
        'fecha': fecha,
        'visto': visto,
        'tipo': tipo,
        'prioridad': prioridad,
      };
}
