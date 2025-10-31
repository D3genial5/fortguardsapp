import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/solicitud_model.dart';

/// Servicio que interactúa con Firebase Firestore para
/// guardar y leer las solicitudes de acceso generadas por los visitantes
/// y gestionadas por los propietarios.
class SolicitudRemoteService {
  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('access_requests');

  /// Guarda una nueva solicitud en Firestore
  static Future<void> guardarSolicitud(SolicitudModel solicitud) async {
    await _collection.add({
      ...solicitud.toJson(),
      // Firestore almacena fechas como Timestamp por conveniencia.
      'fecha': Timestamp.fromDate(solicitud.fecha),
    });
  }

  /// Devuelve un stream de solicitudes pendientes para una casa concreta
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamSolicitudesPendientes(
    String condominio,
    int casaNumero,
  ) {
    return _collection
        .where('condominio', isEqualTo: condominio)
        .where('casaNumero', isEqualTo: casaNumero)
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('fecha', descending: true)
        .snapshots();
  }

  /// Actualiza el campo `estado` del documento indicado
  static Future<void> actualizarEstado(String docId, String nuevoEstado) async {
    await _collection.doc(docId).update({'estado': nuevoEstado});
  }

  /// Obtiene todas las solicitudes realizadas por cierto CI (visitante)
  static Future<List<SolicitudModel>> obtenerPorCi(String ci) async {
    final query = await _collection.where('ci', isEqualTo: ci).get();
    return query.docs.map((d) {
      final data = d.data();
      return SolicitudModel.fromJson({
        ...data,
        'fecha': (data['fecha'] as Timestamp).toDate().toIso8601String(),
      });
    }).toList();
  }
}
