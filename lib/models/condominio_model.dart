class CondominioModel {
  final String id;
  final String nombre;
  final List<String> casas;

  CondominioModel({
    required this.id,
    required this.nombre,
    required this.casas,
  });

  factory CondominioModel.fromJson(Map<String, dynamic> json) {
    return CondominioModel(
      id: json['id'],
      nombre: json['nombre'],
      casas: List<String>.from(json['casas']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'casas': casas,
    };
  }
}
