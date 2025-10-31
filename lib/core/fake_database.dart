import '../models/propietario_model.dart';

final List<Map<String, dynamic>> propietariosFake = [
  // Los Alamos - Casa 1 (existente)
  {
    'condominio': 'Los Alamos',
    'casa': 1,
    'password': '1234',
    'personas': [
      'Douglas Acosta Castillo',
      'María Cristina Soruco',
      'Leonardo Acosta Soruco',
      'Carlos Andrés Acosta',
    ],
  },
  // Los Alamos - Casa 2 (nueva)
  {
    'condominio': 'Los Alamos',
    'casa': 2,
    'password': '2222',
    'personas': [
      'Roberto Méndez',
      'Ana María García',
    ],
  },
  // El Bosque - Casa 1 (nueva)
  {
    'condominio': 'El Bosque',
    'casa': 1,
    'password': '1111',
    'personas': [
      'Miguel Ángel Rojas',
      'Patricia Flores',
      'Sebastián Rojas',
    ],
  },
  // El Bosque - Casa 2 (existente)
  {
    'condominio': 'El Bosque',
    'casa': 2,
    'password': '5678',
    'personas': [
      'Carlos Acosta',
      'Lucía Romero',
    ],
  },
  // Villa del Rocío - Casa 1
  {
    'condominio': 'Villa del Rocio',
    'casa': 1,
    'password': '1010',
    'personas': [
      'Fernando Bustamante',
      'Elena Vargas',
    ],
  },
  // Villa del Rocío - Casa 2
  {
    'condominio': 'Villa del Rocio',
    'casa': 2,
    'password': '2020',
    'personas': [
      'Jorge Ramírez',
      'Claudia Torrez',
      'Mateo Ramírez',
    ],
  },
  // Villa del Rocío - Casa 3
  {
    'condominio': 'Villa del Rocio',
    'casa': 3,
    'password': '3030',
    'personas': [
      'Marcelo Gómez',
      'Verónica Suárez',
    ],
  },
  // Villa del Rocío - Casa 4
  {
    'condominio': 'Villa del Rocio',
    'casa': 4,
    'password': '4040',
    'personas': [
      'Luis Herrera',
      'Carmen Daza',
      'Daniel Herrera',
      'Sofía Herrera',
    ],
  },
];

/// Busca un propietario que coincida con los datos ingresados
PropietarioModel? buscarPropietario(String condominio, int casa, String password) {
  final encontrado = propietariosFake.firstWhere(
    (prop) =>
        prop['condominio'].toLowerCase() == condominio.toLowerCase() &&
        prop['casa'] == casa &&
        prop['password'] == password,
    orElse: () => {},
  );

  if (encontrado.isEmpty) return null;

  return PropietarioModel(
    condominio: encontrado['condominio'],
    casa: Casa(nombre: 'Casa', numero: encontrado['casa']),
    codigoCasa: '000',
    personas: List<String>.from(encontrado['personas']),
  );
}
