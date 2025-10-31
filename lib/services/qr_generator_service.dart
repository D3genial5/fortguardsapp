import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qr_payload_model.dart';

/// Servicio para generar QRs seguros con firma HMAC
class QrGeneratorService {
  static final _firestore = FirebaseFirestore.instance;

  /// Clave secreta por defecto (en producción, usar Cloud Function o secret manager)
  /// TODO: Mover a Cloud Function para mayor seguridad
  static const _defaultSecret = 'fortguards_secret_2024_v1';

  /// Genera un QR para propietario/casa
  static Future<String> generateForPropietario({
    required String condominio,
    required int casaNumero,
    required String codigoCasa,
    int validityHours = 12,
    int? usosMaximos,
  }) async {
    try {
      final now = DateTime.now();
      final iat = now.millisecondsSinceEpoch;
      final exp = now.add(Duration(hours: validityHours)).millisecondsSinceEpoch;

      // Obtener secret específico del condominio (si existe)
      final secret = await _getCondominioSecret(condominio);

      final payload = QrPayloadModel(
        condominio: condominio,
        casaNumero: casaNumero,
        codigoCasa: codigoCasa,
        issuedAt: iat,
        expiresAt: exp,
        usosMaximos: usosMaximos,
      );

      // Calcular firma HMAC
      final signature = payload.calculateHmac(secret);
      final signedPayload = payload.copyWithSignature(signature);

      dev.log('QR generado para casa $casaNumero en $condominio', name: 'QrGenerator');
      return signedPayload.toJsonString();
    } catch (e) {
      dev.log('Error generando QR: $e', name: 'QrGenerator');
      rethrow;
    }
  }

  /// Genera un QR para invitado (con hash del CI)
  static Future<String> generateForInvitado({
    required String condominio,
    required int casaNumero,
    required String codigoCasa,
    required String visitanteCi,
    int validityHours = 12,
    int? usosMaximos,
  }) async {
    try {
      final now = DateTime.now();
      final iat = now.millisecondsSinceEpoch;
      final exp = now.add(Duration(hours: validityHours)).millisecondsSinceEpoch;

      // Obtener secret específico del condominio
      final secret = await _getCondominioSecret(condominio);

      // Hash del CI para no exponer PII
      final ciHash = QrPayloadModel.hashVisitanteCi(visitanteCi, condominio);

      final payload = QrPayloadModel(
        condominio: condominio,
        casaNumero: casaNumero,
        codigoCasa: codigoCasa,
        issuedAt: iat,
        expiresAt: exp,
        usosMaximos: usosMaximos,
        visitanteCiHash: ciHash,
      );

      // Calcular firma HMAC
      final signature = payload.calculateHmac(secret);
      final signedPayload = payload.copyWithSignature(signature);

      dev.log('QR generado para invitado en casa $casaNumero', name: 'QrGenerator');
      return signedPayload.toJsonString();
    } catch (e) {
      dev.log('Error generando QR para invitado: $e', name: 'QrGenerator');
      rethrow;
    }
  }

  /// Genera un QR desde una solicitud de acceso aceptada
  static Future<String> generateFromAccessRequest({
    required String condominio,
    required int casaNumero,
    required String codigoCasa,
    required String visitanteCi,
    String? tipoAcceso,
    int? usosMaximos,
    DateTime? fechaExpiracion,
  }) async {
    try {
      final now = DateTime.now();
      final iat = now.millisecondsSinceEpoch;
      
      // Determinar expiración según tipo de acceso
      int exp;
      int? usos;

      if (tipoAcceso == 'tiempo' && fechaExpiracion != null) {
        exp = fechaExpiracion.millisecondsSinceEpoch;
        usos = 999999; // Valor alto para acceso por tiempo
      } else if (tipoAcceso == 'indefinido') {
        exp = now.add(const Duration(days: 365)).millisecondsSinceEpoch; // 1 año
        usos = 999999; // Valor alto para acceso indefinido
      } else {
        // Por usos o default
        exp = now.add(const Duration(hours: 12)).millisecondsSinceEpoch;
        usos = usosMaximos ?? 1;
      }

      return generateForInvitado(
        condominio: condominio,
        casaNumero: casaNumero,
        codigoCasa: codigoCasa,
        visitanteCi: visitanteCi,
        validityHours: ((exp - iat) / 3600000).ceil(),
        usosMaximos: usos,
      );
    } catch (e) {
      dev.log('Error generando QR desde solicitud: $e', name: 'QrGenerator');
      rethrow;
    }
  }

  /// Obtiene el secret del condominio (o usa el default)
  static Future<String> _getCondominioSecret(String condominio) async {
    try {
      final doc = await _firestore
          .collection('condominios')
          .doc(condominio)
          .get();

      if (doc.exists) {
        final secret = doc.data()?['qrSecret'] as String?;
        if (secret != null && secret.isNotEmpty) {
          return secret;
        }
      }

      // Si no existe secret, usar default
      return _defaultSecret;
    } catch (e) {
      dev.log('Error obteniendo secret, usando default: $e', name: 'QrGenerator');
      return _defaultSecret;
    }
  }

  /// Genera un hash del payload para auditoría
  static String generatePayloadHash(String payloadJson) {
    final bytes = utf8.encode(payloadJson);
    // Simple hash para identificación (no es crítico para seguridad)
    return bytes.fold(0, (prev, byte) => prev + byte).toString();
  }
}
