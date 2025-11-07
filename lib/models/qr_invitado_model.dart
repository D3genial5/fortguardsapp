import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de QR según criterios de validez
enum TipoQr {
  permanente, // Sin límites
  porTiempo,  // Solo expira por fecha
  porUso,     // Solo expira por usos
  mixto,      // Expira por fecha o usos (lo que ocurra primero)
}

/// Estados posibles del QR
enum EstadoQr {
  activo,
  sinUsos,
  expirado,
  revocado,
}

class QrInvitadoModel {
  final String codigo;          // ID único del QR (payload)
  final String condominio;      // Condominio del propietario
  final int casaNumero;         // Número de casa
  final TipoQr tipo;            // Tipo de QR
  final String invitadoNombre;  // Nombre completo del invitado
  final String invitadoCi;      // CI del invitado
  final String? placaVehiculo;  // Placa (opcional)
  final int? usosRestantes;     // null si es permanente o por tiempo
  final DateTime? expira;       // null si es permanente o por uso
  final String creadoPor;       // propietarioId
  final DateTime creadoEn;      // Fecha de creación
  final EstadoQr estado;        // Estado actual

  QrInvitadoModel({
    required this.codigo,
    required this.condominio,
    required this.casaNumero,
    required this.tipo,
    required this.invitadoNombre,
    required this.invitadoCi,
    this.placaVehiculo,
    this.usosRestantes,
    this.expira,
    required this.creadoPor,
    required this.creadoEn,
    this.estado = EstadoQr.activo,
  });

  /// Convierte el modelo a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'codigo': codigo,
      'condominio': condominio,
      'casaNumero': casaNumero,
      'tipo': tipo.name,
      'invitadoNombre': invitadoNombre,
      'invitadoCi': invitadoCi,
      'placaVehiculo': placaVehiculo,
      'usosRestantes': usosRestantes,
      'expira': expira != null ? Timestamp.fromDate(expira!) : null,
      'creadoPor': creadoPor,
      'creadoEn': Timestamp.fromDate(creadoEn),
      'estado': estado.name,
    };
  }

  /// Crea el modelo desde Firestore
  factory QrInvitadoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QrInvitadoModel(
      codigo: data['codigo'] ?? doc.id,
      condominio: data['condominio'] ?? '',
      casaNumero: data['casaNumero'] ?? 0,
      tipo: TipoQr.values.firstWhere(
        (t) => t.name == data['tipo'],
        orElse: () => TipoQr.permanente,
      ),
      invitadoNombre: data['invitadoNombre'] ?? '',
      invitadoCi: data['invitadoCi'] ?? '',
      placaVehiculo: data['placaVehiculo'],
      usosRestantes: data['usosRestantes'],
      expira: data['expira'] != null
          ? (data['expira'] as Timestamp).toDate()
          : null,
      creadoPor: data['creadoPor'] ?? '',
      creadoEn: data['creadoEn'] != null
          ? (data['creadoEn'] as Timestamp).toDate()
          : DateTime.now(),
      estado: EstadoQr.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoQr.activo,
      ),
    );
  }

  /// Verifica si el QR es válido (no expirado, con usos, etc.)
  bool get esValido {
    if (estado != EstadoQr.activo) return false;

    // Verificar expiración por fecha
    if (expira != null && DateTime.now().isAfter(expira!)) {
      return false;
    }

    // Verificar expiración por usos
    if (usosRestantes != null && usosRestantes! <= 0) {
      return false;
    }

    return true;
  }

  /// Obtiene el mensaje de estado legible
  String get mensajeEstado {
    switch (estado) {
      case EstadoQr.activo:
        return 'Activo';
      case EstadoQr.sinUsos:
        return 'Sin usos restantes';
      case EstadoQr.expirado:
        return 'Expirado';
      case EstadoQr.revocado:
        return 'Revocado';
    }
  }

  /// Obtiene una descripción del tipo de QR
  String get tipoDescripcion {
    switch (tipo) {
      case TipoQr.permanente:
        return 'Permanente';
      case TipoQr.porTiempo:
        return 'Por tiempo';
      case TipoQr.porUso:
        return 'Por uso (${usosRestantes ?? 0} restantes)';
      case TipoQr.mixto:
        return 'Mixto';
    }
  }

  /// Crea una copia con campos modificados
  QrInvitadoModel copyWith({
    String? codigo,
    String? condominio,
    int? casaNumero,
    TipoQr? tipo,
    String? invitadoNombre,
    String? invitadoCi,
    String? placaVehiculo,
    int? usosRestantes,
    DateTime? expira,
    String? creadoPor,
    DateTime? creadoEn,
    EstadoQr? estado,
  }) {
    return QrInvitadoModel(
      codigo: codigo ?? this.codigo,
      condominio: condominio ?? this.condominio,
      casaNumero: casaNumero ?? this.casaNumero,
      tipo: tipo ?? this.tipo,
      invitadoNombre: invitadoNombre ?? this.invitadoNombre,
      invitadoCi: invitadoCi ?? this.invitadoCi,
      placaVehiculo: placaVehiculo ?? this.placaVehiculo,
      usosRestantes: usosRestantes ?? this.usosRestantes,
      expira: expira ?? this.expira,
      creadoPor: creadoPor ?? this.creadoPor,
      creadoEn: creadoEn ?? this.creadoEn,
      estado: estado ?? this.estado,
    );
  }
}
