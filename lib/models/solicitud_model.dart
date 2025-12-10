class SolicitudModel {
  final String? docId; // ID del documento en Firestore
  final String nombre;
  final String apellidos;
  final String ci;
  final String condominio;
  final int casaNumero;
  final DateTime fecha;
  final String estado; // 'pendiente', 'aceptada', 'rechazada'
  final int? usosRestantes;
  final DateTime? expira;
  final String? tipoAcceso; // 'usos', 'tiempo', 'indefinido'
  final DateTime? fechaExpiracion;
  final String? codigoQr; // Código único del QR

  SolicitudModel({
    this.docId,
    required this.nombre,
    required this.apellidos,
    required this.ci,
    required this.condominio,
    required this.casaNumero,
    required this.fecha,
    required this.estado,
    this.usosRestantes,
    this.expira,
    this.tipoAcceso,
    this.fechaExpiracion,
    this.codigoQr,
  });

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    return SolicitudModel(
      docId: json['docId'],
      nombre: json['nombre'] ?? '',
      apellidos: json['apellidos'] ?? '',
      ci: json['ci'] ?? '',
      condominio: json['condominio'] ?? '',
      casaNumero: json['casaNumero'] ?? 0,
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      estado: json['estado'] ?? 'pendiente',
      usosRestantes: json['usosRestantes'],
      expira: json['expira'] != null ? DateTime.tryParse(json['expira']) : null,
      tipoAcceso: json['tipoAcceso'],
      fechaExpiracion: json['fechaExpiracion'] != null ? DateTime.tryParse(json['fechaExpiracion']) : null,
      codigoQr: json['codigoQr'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (docId != null) 'docId': docId,
      'nombre': nombre,
      'apellidos': apellidos,
      'ci': ci,
      'condominio': condominio,
      'casaNumero': casaNumero,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      if (usosRestantes != null) 'usosRestantes': usosRestantes,
      if (expira != null) 'expira': expira!.toIso8601String(),
      if (tipoAcceso != null) 'tipoAcceso': tipoAcceso,
      if (fechaExpiracion != null) 'fechaExpiracion': fechaExpiracion!.toIso8601String(),
      if (codigoQr != null) 'codigoQr': codigoQr,
    };
  }
  
  /// Helper para obtener descripción del tipo de acceso
  String get descripcionAcceso {
    switch (tipoAcceso) {
      case 'indefinido':
        return 'Acceso indefinido';
      case 'tiempo':
        if (fechaExpiracion != null) {
          final ahora = DateTime.now();
          final diferencia = fechaExpiracion!.difference(ahora);
          if (diferencia.isNegative) {
            return 'Expirado';
          } else if (diferencia.inDays > 0) {
            return '${diferencia.inDays}d restantes';
          } else if (diferencia.inHours > 0) {
            return '${diferencia.inHours}h restantes';
          } else {
            return '${diferencia.inMinutes}m restantes';
          }
        }
        return 'Por tiempo';
      case 'usos':
      default:
        return '${usosRestantes ?? 0} usos restantes';
    }
  }
}
