import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:developer' as dev;

class PropietarioAuthService {
  static final _db = FirebaseFirestore.instance;

  /// Hash SHA256 con sal — misma implementación que admin_fortguards.
  static String _hashWithSalt(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Inicia sesión para propietarios.
  /// Verifica hash con sal. Si encuentra password legacy (plain-text), lo migra automáticamente.
  static Future<Map<String, dynamic>?> loginPropietario({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    final inputCondo = condominioId.trim();
    final inputCondoLower = inputCondo.toLowerCase();
    final inputCasaId = casaId.trim();
    try {
      // Buscar referencia del condominio
      DocumentReference<Map<String, dynamic>>? condoRef;

      final directDoc = await _db.collection('condominios').doc(inputCondo).get();
      if (directDoc.exists) {
        condoRef = directDoc.reference;
      } else {
        // Búsqueda case-insensitive
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

      if (condoRef == null) return null;

      // Buscar casa
      var casaSnapshot = await condoRef.collection('casas').doc(inputCasaId).get();
      if (!casaSnapshot.exists) {
        final altCasaId = int.tryParse(inputCasaId)?.toString();
        if (altCasaId != null && altCasaId != inputCasaId) {
          casaSnapshot = await condoRef.collection('casas').doc(altCasaId).get();
        }
      }

      if (!casaSnapshot.exists) return null;

      final data = casaSnapshot.data()!;
      final storedHash = data['passwordHash'] as String?;
      final storedSalt = data['passwordSalt'] as String?;
      final storedPlain = data['password'] as String?;

      // 1. Verificar hash con sal
      if (storedHash != null && storedSalt != null) {
        if (_hashWithSalt(password, storedSalt) == storedHash) {
          return _buildResult(casaSnapshot, condoRef.id, data);
        }
        return null; // Hash no coincide
      }

      // 2. Migración legacy: plain-text → hash con sal
      if (storedPlain != null && storedPlain == password) {
        final newSalt = _generateSimpleSalt();
        final hash = _hashWithSalt(password, newSalt);

        await casaSnapshot.reference.update({
          'passwordHash': hash,
          'passwordSalt': newSalt,
          'password': FieldValue.delete(),
        });
        dev.log('Propietario migrado a hash: ${condoRef.id} casa ${casaSnapshot.id}');

        return _buildResult(casaSnapshot, condoRef.id, data);
      }

      return null;
    } catch (e) {
      dev.log('Error en loginPropietario', error: e);
      return null;
    }
  }

  static String _generateSimpleSalt() {
    final now = DateTime.now();
    final raw = '${now.microsecondsSinceEpoch}${now.hashCode}';
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString().substring(0, 22);
  }

  static Map<String, dynamic> _buildResult(
    DocumentSnapshot<Map<String, dynamic>> casaDoc,
    String condominioId,
    Map<String, dynamic> data,
  ) {
    final numero = data['numero'] ?? int.tryParse(casaDoc.id);
    return {
      'condominio': condominioId,
      'casa': {
        'nombre': casaDoc.id,
        'numero': numero,
      },
      'codigoCasa': casaDoc.id,
      'personas':
          (data['residentes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    };
  }
}
