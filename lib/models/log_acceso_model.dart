import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado del intento de acceso
enum ResultadoAcceso {
  aceptado,
  denegado,
  qrInvalido,
  sinUsos,
  expirado,
}

class LogAccesoModel {
  final String? id;
  final String qrCodigo;          // Código del QR escaneado
  final String guardiaId;         // ID del guardia que escaneó
  final String guardiaNombre;     // Nombre del guardia
  final String condominio;        // Condominio
  final int casaNumero;           // Casa del invitado
  final String invitadoNombre;    // Nombre del invitado
  final String invitadoCi;        // CI del invitado
  final String? placaVehiculo;    // Placa (opcional)
  final DateTime fecha;           // Fecha y hora del acceso
  final ResultadoAcceso resultado; // Resultado del acceso
  final String? observaciones;    // Notas adicionales (opcional)

  LogAccesoModel({
    this.id,
    required this.qrCodigo,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.condominio,
    required this.casaNumero,
    required this.invitadoNombre,
    required this.invitadoCi,
    this.placaVehiculo,
    required this.fecha,
    required this.resultado,
    this.observaciones,
  });

  /// Convierte el modelo a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'qrCodigo': qrCodigo,
      'guardiaId': guardiaId,
      'guardiaNombre': guardiaNombre,
      'condominio': condominio,
      'casaNumero': casaNumero,
      'invitadoNombre': invitadoNombre,
      'invitadoCi': invitadoCi,
      'placaVehiculo': placaVehiculo,
      'fecha': Timestamp.fromDate(fecha),
      'resultado': resultado.name,
      'observaciones': observaciones,
    };
  }

  /// Crea el modelo desde Firestore
  factory LogAccesoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LogAccesoModel(
      id: doc.id,
      qrCodigo: data['qrCodigo'] ?? '',
      guardiaId: data['guardiaId'] ?? '',
      guardiaNombre: data['guardiaNombre'] ?? '',
      condominio: data['condominio'] ?? '',
      casaNumero: data['casaNumero'] ?? 0,
      invitadoNombre: data['invitadoNombre'] ?? '',
      invitadoCi: data['invitadoCi'] ?? '',
      placaVehiculo: data['placaVehiculo'],
      fecha: data['fecha'] != null
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      resultado: ResultadoAcceso.values.firstWhere(
        (r) => r.name == data['resultado'],
        orElse: () => ResultadoAcceso.denegado,
      ),
      observaciones: data['observaciones'],
    );
  }

  /// Obtiene el mensaje legible del resultado
  String get mensajeResultado {
    switch (resultado) {
      case ResultadoAcceso.aceptado:
        return 'Acceso aceptado';
      case ResultadoAcceso.denegado:
        return 'Acceso denegado';
      case ResultadoAcceso.qrInvalido:
        return 'QR inválido';
      case ResultadoAcceso.sinUsos:
        return 'Sin usos restantes';
      case ResultadoAcceso.expirado:
        return 'QR expirado';
    }
  }
}
