import '../core/app_log.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Login de propietario contra Cloud Function `loginPropietario`.
///
/// Flujo seguro:
///   1. Llama a la Cloud Function con condominio/casa/password.
///   2. La función valida (PBKDF2 server-side) y emite un Custom Token.
///   3. La app firma en Firebase Auth con `signInWithCustomToken`.
///   4. Todas las llamadas Firestore posteriores se hacen con auth.token
///      conteniendo `{role: 'propietario', condominio, casaId}` y son
///      validadas por las reglas Firestore.
class PropietarioAuthService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Inicia sesión para propietarios.
  ///
  /// Devuelve `null` si las credenciales son inválidas.
  /// Lanza si la red falla o si el servidor responde con un error inesperado.
  static Future<Map<String, dynamic>?> loginPropietario({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    try {
      if (kDebugMode) AppLog.log('🔵 Llamando loginPropietario CF...');
      final callable = _functions.httpsCallable(
        'loginPropietario',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call(<String, dynamic>{
        'condominio': condominioId.trim(),
        'casaId': casaId.trim(),
        'password': password,
      });

      if (kDebugMode) AppLog.log('🟢 CF respondió OK');

      final data = result.data as Map?;
      final token = data?['token'] as String?;
      if (token == null) {
        if (kDebugMode) AppLog.log('🔴 Token vacío');
        return null;
      }

      if (kDebugMode) {
        AppLog.log('🔵 Firmando con Custom Token (len=${token.length})...');
      }
      // Firma en Firebase Auth con Custom Token
      final cred = await _auth.signInWithCustomToken(token);
      if (kDebugMode) AppLog.log('🟢 signInWithCustomToken OK uid=${cred.user?.uid}');

      final condoIdResp = data!['condominio'] as String;
      final casaIdResp = data['casaId'] as String;
      final casaNumero = data['casaNumero'] as int? ?? int.tryParse(casaIdResp);
      final residentes = (data['residentes'] as List?)?.cast<String>() ?? const [];

      return {
        'condominio': condoIdResp,
        'casa': {
          'nombre': casaIdResp,
          'numero': casaNumero,
        },
        'codigoCasa': casaIdResp,
        'personas': residentes,
        'propietario': data['propietario'] ?? '',
      };
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        AppLog.log('🔴 FunctionsException: code=${e.code} message=${e.message}');
      }
      if (e.code == 'unauthenticated' || e.code == 'not-found') return null;
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        AppLog.log('🔴 AuthException: code=${e.code} message=${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) AppLog.log('🔴 loginPropietario error inesperado: $e');
      rethrow;
    }
  }

  /// Cambia la contraseña del propietario autenticado.
  /// Devuelve `true` si se cambió, `false` si la actual no coincide.
  static Future<bool> changePassword({
    required String passwordActual,
    required String nuevaPassword,
  }) async {
    try {
      final callable = _functions.httpsCallable('changePropietarioPassword');
      await callable.call(<String, dynamic>{
        'passwordActual': passwordActual,
        'nuevaPassword': nuevaPassword,
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') return false;
      rethrow;
    }
  }

  /// Cierra la sesión actual.
  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) AppLog.log('logout error: $e');
    }
  }

  /// Usuario auth actual (propietario).
  static User? get currentUser => _auth.currentUser;
}
