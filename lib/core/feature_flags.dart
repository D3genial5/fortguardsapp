/// Flags de funcionalidades para habilitar/deshabilitar features sin borrar
/// código. Centraliza los toggles del producto.
class FeatureFlags {
  FeatureFlags._();

  /// OCR de la cédula en el registro de visita.
  ///
  /// Diferido: la implementación real del OCR queda para un update posterior.
  /// Mientras esté en `false`, el registro NO exige validación por cámara y el
  /// usuario escribe el C.I. a mano.
  static const bool ocrEnabled = false;
}
