import 'package:cloud_firestore/cloud_firestore.dart';

class CondominioService {
  static final _db = FirebaseFirestore.instance;

  // Stream de todos los IDs de condominios (nombre de los documentos)
  static Stream<List<String>> streamCondominios() {
    return _db.collection('condominios').snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toList(),
        );
  }

  // Stream de los números de casa de un condominio
  static Stream<List<int>> streamCasas(String condominioId) {
    return _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .snapshots()
        .map((snap) {
          final numeros = <int>[];
          for (final d in snap.docs) {
            final raw = d.data()['numero'];
            int? n;
            if (raw is int) {
              n = raw;
            } else if (raw is String) {
              n = int.tryParse(raw);
            }
            // fallback: intenta con el ID del doc
            n ??= int.tryParse(d.id);
            if (n != null) numeros.add(n);
          }
          numeros.sort();
          return numeros;
        });
  }
}
