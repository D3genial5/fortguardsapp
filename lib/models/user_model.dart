enum RolUsuario {
  propietario,
  administrador,
  personal,
}

class UserModel {
  final String id;
  final String nombre;
  final String email;
  final RolUsuario rol;
  final String? idCasa;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.idCasa,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      nombre: json['nombre'],
      email: json['email'],
      rol: _rolFromString(json['rol']),
      idCasa: json['idCasa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol.name,
      'idCasa': idCasa,
    };
  }

  static RolUsuario _rolFromString(String rolString) {
    switch (rolString) {
      case 'propietario':
        return RolUsuario.propietario;
      case 'administrador':
        return RolUsuario.administrador;
      case 'personal':
        return RolUsuario.personal;
      default:
        throw Exception('Rol no válido: $rolString');
    }
  }
}
