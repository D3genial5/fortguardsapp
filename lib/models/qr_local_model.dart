class QrLocalModel {
  final String codigo; // Código cifrado o texto que representa el QR
  final String condominio;
  final int casa;
  final DateTime expira;
  final int usosRestantes;
  final String? propietarioId; // ID único del propietario
  final String? propietarioNombre; // Nombre del propietario para verificación

  QrLocalModel({
    required this.codigo,
    required this.condominio,
    required this.casa,
    required this.expira,
    required this.usosRestantes,
    this.propietarioId,
    this.propietarioNombre,
  });

  factory QrLocalModel.fromJson(Map<String, dynamic> json) {
    return QrLocalModel(
      codigo: json['codigo'] as String,
      condominio: json['condominio'] as String,
      casa: json['casa'] as int,
      expira: DateTime.parse(json['expira'] as String),
      usosRestantes: json['usosRestantes'] as int,
      propietarioId: json['propietarioId'] as String?,
      propietarioNombre: json['propietarioNombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'condominio': condominio,
        'casa': casa,
        'expira': expira.toIso8601String(),
        'usosRestantes': usosRestantes,
        'propietarioId': propietarioId,
        'propietarioNombre': propietarioNombre,
      };
}
