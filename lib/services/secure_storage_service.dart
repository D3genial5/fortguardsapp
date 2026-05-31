import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro de los datos del visitante (nombre y C.I.) para
/// reutilizarlos entre sesiones sin volver a pedirlos. Usa
/// `flutter_secure_storage` (Keychain en iOS / EncryptedSharedPreferences en
/// Android).
class SecureStorageService {
  SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kNombre = 'visitante_nombre';
  static const String _kCi = 'visitante_ci';

  static Future<String?> getVisitanteNombre() => _storage.read(key: _kNombre);

  static Future<String?> getVisitanteCi() => _storage.read(key: _kCi);

  static Future<void> saveVisitanteNombre(String nombre) =>
      _storage.write(key: _kNombre, value: nombre);

  static Future<void> saveVisitanteCi(String ci) =>
      _storage.write(key: _kCi, value: ci);

  static Future<void> clear() async {
    await _storage.delete(key: _kNombre);
    await _storage.delete(key: _kCi);
  }
}
