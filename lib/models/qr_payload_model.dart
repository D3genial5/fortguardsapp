import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Modelo del payload del QR con firma HMAC
class QrPayloadModel {
  final String condominio; // c
  final int casaNumero; // h
  final String codigoCasa; // k
  final int issuedAt; // iat - epoch milliseconds
  final int expiresAt; // exp - epoch milliseconds
  final int? usosMaximos; // u - opcional
  final String? visitanteCiHash; // vci - hash del CI del visitante (opcional)
  final String? signature; // sig - HMAC-SHA256

  QrPayloadModel({
    required this.condominio,
    required this.casaNumero,
    required this.codigoCasa,
    required this.issuedAt,
    required this.expiresAt,
    this.usosMaximos,
    this.visitanteCiHash,
    this.signature,
  });

  /// Crea el payload desde JSON
  factory QrPayloadModel.fromJson(Map<String, dynamic> json) {
    return QrPayloadModel(
      condominio: json['c'] as String,
      casaNumero: json['h'] as int,
      codigoCasa: json['k'] as String,
      issuedAt: json['iat'] as int,
      expiresAt: json['exp'] as int,
      usosMaximos: json['u'] as int?,
      visitanteCiHash: json['vci'] as String?,
      signature: json['sig'] as String?,
    );
  }

  /// Convierte a JSON (sin firma para calcular HMAC)
  Map<String, dynamic> toJson({bool includeSig = true}) {
    final map = <String, dynamic>{
      'c': condominio,
      'h': casaNumero,
      'k': codigoCasa,
      'iat': issuedAt,
      'exp': expiresAt,
    };

    if (usosMaximos != null) map['u'] = usosMaximos;
    if (visitanteCiHash != null) map['vci'] = visitanteCiHash;
    if (includeSig && signature != null) map['sig'] = signature;

    return map;
  }

  /// Convierte a string JSON
  String toJsonString({bool includeSig = true}) {
    return jsonEncode(toJson(includeSig: includeSig));
  }

  /// Genera el hash del CI del visitante
  static String hashVisitanteCi(String ci, String salt) {
    final bytes = utf8.encode('$ci:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Calcula HMAC-SHA256 del payload (sin signature)
  String calculateHmac(String secret) {
    final payloadWithoutSig = toJsonString(includeSig: false);
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payloadWithoutSig);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Verifica la firma HMAC
  bool verifySignature(String secret) {
    if (signature == null) return false;
    final expectedSig = calculateHmac(secret);
    return signature == expectedSig;
  }

  /// Verifica si el QR está expirado
  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > expiresAt;
  }

  /// Verifica si el QR es válido en tiempo
  bool get isValid {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now >= issuedAt && now <= expiresAt;
  }

  /// Tiempo restante en minutos
  int get minutesRemaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = expiresAt - now;
    return diff > 0 ? (diff / 60000).ceil() : 0;
  }

  /// Crea una copia con firma
  QrPayloadModel copyWithSignature(String sig) {
    return QrPayloadModel(
      condominio: condominio,
      casaNumero: casaNumero,
      codigoCasa: codigoCasa,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      usosMaximos: usosMaximos,
      visitanteCiHash: visitanteCiHash,
      signature: sig,
    );
  }
}
