import 'package:cloud_firestore/cloud_firestore.dart';

class CondominioService {
  static final _db = FirebaseFirestore.instance;

  // Stream de todos los IDs de condominios (nombre de los documentos)
  static Stream<List<String>> streamCondominios() {
    return _db.collection('condominios').snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toList(),
        );
  }

  // Stream de los identificadores de casa de un condominio.
  // Pueden ser numéricos ("21") o texto ("Acacia 21"); se ordenan
  // numéricamente cuando ambos lo son, alfabéticamente si no.
  static Stream<List<String>> streamCasas(String condominioId) {
    return _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .snapshots()
        .map((snap) {
          final numeros = <String>[];
          for (final d in snap.docs) {
            final raw = d.data()['numero']?.toString().trim();
            final n = (raw == null || raw.isEmpty) ? d.id : raw;
            if (n.isNotEmpty) numeros.add(n);
          }
          numeros.sort((a, b) {
            final na = int.tryParse(a);
            final nb = int.tryParse(b);
            if (na != null && nb != null) return na.compareTo(nb);
            if (na != null) return -1;
            if (nb != null) return 1;
            return a.toLowerCase().compareTo(b.toLowerCase());
          });
          return numeros;
        });
  }
}
