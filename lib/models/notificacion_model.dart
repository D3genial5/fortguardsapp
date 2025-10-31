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

  NotificacionModel({
    required this.id,
    required this.condominio,
    required this.casaNumero,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.visto,
    required this.tipo,
  });

  factory NotificacionModel.fromDoc(String id, Map<String, dynamic> data) {
    return NotificacionModel(
      id: id,
      condominio: data['condominio'] ?? '',
      casaNumero: data['casaNumero'] ?? 0,
      titulo: data['titulo'] ?? '',
      mensaje: data['mensaje'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
      visto: data['visto'] ?? false,
      tipo: data['tipo'] ?? 'privada',
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
      };
}
