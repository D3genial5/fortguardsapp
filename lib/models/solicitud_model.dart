class SolicitudModel {
  final String nombre;
  final String apellidos;
  final String ci;
  final String condominio;
  final int casaNumero;
  final DateTime fecha;
  final String estado; // 'pendiente', 'aceptada', 'rechazada'
  final int? usosRestantes;
  final DateTime? expira;

  SolicitudModel({
    required this.nombre,
    required this.apellidos,
    required this.ci,
    required this.condominio,
    required this.casaNumero,
    required this.fecha,
    required this.estado,
    this.usosRestantes,
    this.expira,
  });

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    return SolicitudModel(
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      ci: json['ci'],
      condominio: json['condominio'],
      casaNumero: json['casaNumero'],
      fecha: DateTime.parse(json['fecha']),
      estado: json['estado'],
      usosRestantes: json['usosRestantes'],
      expira: json['expira'] != null ? DateTime.parse(json['expira']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'apellidos': apellidos,
      'ci': ci,
      'condominio': condominio,
      'casaNumero': casaNumero,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      if (usosRestantes != null) 'usosRestantes': usosRestantes,
      if (expira != null) 'expira': expira!.toIso8601String(),
    };
  }
}
