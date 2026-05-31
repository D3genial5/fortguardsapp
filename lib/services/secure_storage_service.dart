import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro para datos sensibles.
/// Usa EncryptedSharedPreferences en Android y Keychain en iOS.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const _keyVisitanteCi = 'visitante_ci';
  static const _keyVisitanteNombre = 'visitante_nombre';
  static const _keyFcmToken = 'fcm_token';

  // ── Visitante CI ──
  static Future<void> saveVisitanteCi(String ci) =>
      _storage.write(key: _keyVisitanteCi, value: ci);

  static Future<String?> getVisitanteCi() =>
      _storage.read(key: _keyVisitanteCi);

  static Future<void> deleteVisitanteCi() =>
      _storage.delete(key: _keyVisitanteCi);

  // ── Visitante Nombre ──
  static Future<void> saveVisitanteNombre(String nombre) =>
      _storage.write(key: _keyVisitanteNombre, value: nombre);

  static Future<String?> getVisitanteNombre() =>
      _storage.read(key: _keyVisitanteNombre);

  static Future<void> deleteVisitanteNombre() =>
      _storage.delete(key: _keyVisitanteNombre);

  // ── FCM Token ──
  static Future<void> saveFcmToken(String token) =>
      _storage.write(key: _keyFcmToken, value: token);

  static Future<String?> getFcmToken() =>
      _storage.read(key: _keyFcmToken);

  // ── Limpieza ──
  static Future<void> clearAll() => _storage.deleteAll();
}
