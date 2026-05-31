import 'dart:io';

/// Resultado de la validación OCR de un documento de identidad.
class OcrResult {
  final bool success;
  final String? idNumber;
  final String? reason;

  const OcrResult({required this.success, this.idNumber, this.reason});
}

/// Servicio de OCR para leer el número de C.I. desde las fotos del carnet.
///
/// NOTA: implementación diferida (fuera del alcance actual). Hoy es un stub
/// inerte controlado por `FeatureFlags.ocrEnabled` (apagado). Cuando se decida
/// activar la función, aquí se integrará el OCR real
/// (p. ej. `google_mlkit_text_recognition`) sin tocar las pantallas que lo usan.
class OcrService {
  const OcrService();

  Future<OcrResult> validateId({
    required File frontImage,
    required File backImage,
  }) async {
    // Stub: no realiza OCR. Devuelve éxito neutro (sin número detectado) para
    // no bloquear el flujo si el feature flag llegara a activarse antes de la
    // implementación real.
    return const OcrResult(success: true);
  }
}
