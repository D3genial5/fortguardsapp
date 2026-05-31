import 'dart:async';
import 'dart:convert';
import '../core/app_log.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio único para generar QRs **firmados** vía Cloud Function.
///
/// La firma HMAC vive 100% en el servidor: el cliente solo recibe el payload
/// ya firmado y lo embebe en el QR. Si la app pierde conexión, devuelve el
/// último QR cacheado mientras siga válido.
class QrSecureService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const _cachePrefix = 'fortguards_qr_cache_';

  /// Genera (o reutiliza) un QR firmado.
  ///
  /// - [tipo] = `'propietario'` | `'invitado'`
  /// - [forceRefresh] omite la cache (usar al regenerar)
  static Future<String> getQr({
    required String condominio,
    required int casaNumero,
    required String codigoCasa,
    required String tipo,
    int validityHours = 12,
    int? usosMaximos,
    String? visitanteCi,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        '$_cachePrefix${tipo}_${condominio}_${casaNumero}_${visitanteCi ?? ''}';

    if (!forceRefresh) {
      final cached = await _readCache(cacheKey);
      if (cached != null) return cached;
    }

    final callable = _functions.httpsCallable(
      'signQrPayload',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final result = await callable.call(<String, dynamic>{
      'condominio': condominio,
      'casaNumero': casaNumero,
      'codigoCasa': codigoCasa,
      'tipo': tipo,
      'validityHours': validityHours,
      if (usosMaximos != null) 'usosMaximos': usosMaximos,
      if (visitanteCi != null && visitanteCi.isNotEmpty) 'visitanteCi': visitanteCi,
    });

    final payload = (result.data as Map?)?['qr'];
    if (payload is! Map) {
      throw StateError('Respuesta inválida de signQrPayload');
    }
    final json = jsonEncode(Map<String, dynamic>.from(payload));

    await _writeCache(cacheKey, json, payload['exp'] as int? ?? 0);
    return json;
  }

  /// Borra la cache local (al cerrar sesión)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_cachePrefix)) await prefs.remove(k);
    }
  }

  static Future<String?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final exp = decoded['exp'] as int? ?? 0;
      if (exp <= DateTime.now().millisecondsSinceEpoch + 60_000) {
        // Menos de 1 min de validez → no cachear
        await prefs.remove(key);
        return null;
      }
      return jsonEncode(decoded);
    } catch (e) {
      if (kDebugMode) AppLog.log('QrSecureService cache read error: $e');
      return null;
    }
  }

  static Future<void> _writeCache(String key, String json, int exp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json);
      await prefs.setInt('${key}_exp', exp);
    } catch (e) {
      if (kDebugMode) AppLog.log('QrSecureService cache write error: $e');
    }
  }
}
