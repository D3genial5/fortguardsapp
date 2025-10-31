class Casa {
  final String nombre;
  final int numero;

  Casa({required this.nombre, required this.numero});

  factory Casa.fromJson(Map<String, dynamic> json) {
    return Casa(
      nombre: json['nombre'],
      numero: json['numero'],
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'numero': numero,
      };
}
class PropietarioModel {
  final String condominio;
  final Casa casa;
  final String codigoCasa;
  final List<String> personas;

  PropietarioModel({
    required this.condominio,
    required this.casa,
    required this.codigoCasa,
    required this.personas,
  });

  factory PropietarioModel.fromJson(Map<String, dynamic> json) {
    return PropietarioModel(
      condominio: json['condominio'],
      casa: Casa.fromJson(json['casa']),
      codigoCasa: json['codigoCasa'],
      personas: List<String>.from(json['personas']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condominio': condominio,
      'casa': casa.toJson(),
      'codigoCasa': codigoCasa,
      'personas': personas,
    };
  }

  PropietarioModel copyWith({
    String? condominio,
    Casa? casa,
    String? codigoCasa,
    List<String>? personas,
  }) {
    return PropietarioModel(
      condominio: condominio ?? this.condominio,
      casa: casa ?? this.casa,
      codigoCasa: codigoCasa ?? this.codigoCasa,
      personas: personas ?? this.personas,
    );
  }
}
