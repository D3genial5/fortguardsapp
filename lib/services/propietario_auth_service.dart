import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

class PropietarioAuthService {
  static final _db = FirebaseFirestore.instance;

  /// Inicia sesión para propietarios. Devuelve los datos de la casa si las
  /// credenciales coinciden o null en caso contrario.
  static Future<Map<String, dynamic>?> loginPropietario({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    final inputCondo = condominioId.trim();
    final inputCondoLower = inputCondo.toLowerCase();
    final inputCasaId = casaId.trim();
    try {
      // 1. Intentar acceso directo a la colección 'casas' usando condominioId
      DocumentSnapshot<Map<String, dynamic>>? casaSnapshot;

      // 1. Intentar por docId exacto
      final directDoc = await _db.collection('condominios').doc(inputCondo).get();
      DocumentReference<Map<String, dynamic>>? condoRef;
      if (directDoc.exists) {
        condoRef = directDoc.reference;
      } else {
        // 2. Buscar condominio ignorando mayúsculas/minúsculas
        final allCondoSnap = await _db.collection('condominios').get();
        for (final d in allCondoSnap.docs) {
          final idLower = d.id.toLowerCase();
          final nombreLower = (d.data()['nombre'] ?? '').toString().toLowerCase();
          if (idLower == inputCondoLower || nombreLower == inputCondoLower) {
            condoRef = d.reference;
            break;
          }
        }
      }

      if (condoRef != null) {
        casaSnapshot = await condoRef.collection('casas').doc(inputCasaId).get();
        // Fallback: si no existe, intentar con número sin ceros a la izquierda
        if (!casaSnapshot.exists) {
          final altCasaId = int.tryParse(inputCasaId)?.toString();
          if (altCasaId != null && altCasaId != inputCasaId) {
            casaSnapshot = await condoRef.collection('casas').doc(altCasaId).get();
          }
        }
      }

      if (casaSnapshot != null && casaSnapshot.exists) {
        final data = casaSnapshot.data()!;
        final storedPassword = data['password']?.toString() ?? '';
        if (storedPassword == password) {
          final numero = data['numero'] ?? int.tryParse(casaSnapshot.id);
          return {
            'condominio': condoRef?.id ?? inputCondo,
            'casa': {
              'nombre': casaSnapshot.id,
              'numero': numero,
            },
            'codigoCasa': casaSnapshot.id,
            'personas': (data['residentes'] as List?)?.map((e) => e.toString()).toList() ?? [],
          };
        }
      }
      return null;
    } catch (e) {
      dev.log('Error en loginPropietario', error: e);
      return null;
    }
  }
}
