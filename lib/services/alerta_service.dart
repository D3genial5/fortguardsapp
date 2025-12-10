import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alerta_model.dart';

class AlertaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'alertas';

  /// Enviar una nueva alerta de emergencia
  static Future<String> enviarAlerta({
    required String tipo,
    required int casaNumero,
    required String condominio,
    required String propietarioId,
    required String propietarioNombre,
  }) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        'tipo': tipo,
        'casaNumero': casaNumero,
        'condominio': condominio,
        'propietarioId': propietarioId,
        'propietarioNombre': propietarioNombre,
        'estado': 'activa',
        'atendidaPor': null,
        'atendidaPorNombre': null,
        'atendidaAt': null,
        'creadoAt': FieldValue.serverTimestamp(),
        'notas': null,
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Error al enviar alerta: $e');
    }
  }

  /// Obtener alertas activas de un condominio
  static Stream<List<AlertaModel>> streamAlertasActivas(String condominio) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'activa')
        .orderBy('creadoAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlertaModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Obtener historial de alertas de un condominio
  static Stream<List<AlertaModel>> streamHistorialAlertas(String condominio, {int limite = 50}) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .orderBy('creadoAt', descending: true)
        .limit(limite)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlertaModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Marcar alerta como atendida
  static Future<void> marcarComoAtendida({
    required String alertaId,
    required String guardiaId,
    required String guardiaNombre,
    String? notas,
  }) async {
    try {
      await _firestore.collection(_collection).doc(alertaId).update({
        'estado': 'atendida',
        'atendidaPor': guardiaId,
        'atendidaPorNombre': guardiaNombre,
        'atendidaAt': FieldValue.serverTimestamp(),
        'notas': notas,
      });
    } catch (e) {
      throw Exception('Error al marcar alerta como atendida: $e');
    }
  }

  /// Obtener cantidad de alertas activas
  static Stream<int> streamCantidadAlertasActivas(String condominio) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'activa')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Convertir tipo de alerta a formato Firebase
  static String tipoAlertaToFirebase(String tipoUI) {
    switch (tipoUI) {
      case 'Ambulancia':
        return 'ambulancia';
      case 'Incendio':
        return 'incendio';
      case 'Alerta':
        return 'alerta';
      case 'Necesito ayuda en casa':
        return 'ayuda';
      default:
        return 'alerta';
    }
  }
}
