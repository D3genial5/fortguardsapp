import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CodigoCasaUtil {
  // Guards para evitar condiciones de carrera
  static final Map<String, bool> _regenerando = {};
  static final Map<String, Timer?> _debounceTimers = {};
  /// Genera un código único por propietario y por día.
  static Future<String> obtenerOCrearCodigo({required String identificador}) async {
    final prefs = await SharedPreferences.getInstance();
    final hoy = DateTime.now().toIso8601String().substring(0, 10); // formato: yyyy-MM-dd

    final claveCodigo = 'codigo_$identificador';
    final claveFecha = 'fecha_$identificador';

    final fechaGuardada = prefs.getString(claveFecha);
    String? codigo = prefs.getString(claveCodigo);

    // Si ya existe un código para hoy, lo devolvemos
    if (fechaGuardada == hoy && codigo != null) {
      return codigo;
    }

    // Si no, generamos uno nuevo
    final random = Random();
    codigo = List.generate(3, (_) => random.nextInt(10)).join();

    // Guardamos el nuevo código y la fecha
    await prefs.setString(claveCodigo, codigo);
    await prefs.setString(claveFecha, hoy);

    return codigo;
  }
  
  /// Crea un código aleatorio de 3 dígitos
  static String _crearCodigo() {
    final random = Random();
    return List.generate(3, (_) => random.nextInt(10)).join();
  }

  /// Genera un nuevo código con duración y usos personalizados
  static Future<Map<String, dynamic>> generarNuevoCodigo({
    required String identificador,
    required String condominioId,
    required int casaNumero,
    required Duration duracion,
    required int usos,
  }) async {
    // Generar código
    final codigo = _crearCodigo();
    final fechaExpiracion = DateTime.now().add(duracion);
    
    // Guardar en SharedPreferences (incluir duracionHoras para futuras regeneraciones)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('codigo_$identificador', codigo);
    await prefs.setString('fecha_$identificador', DateTime.now().toIso8601String());
    await prefs.setString('expira_$identificador', fechaExpiracion.toIso8601String());
    await prefs.setInt('usos_$identificador', usos);
    await prefs.setInt('duracionHoras_$identificador', duracion.inHours);
    
    // Guardar en Firestore
    await FirebaseFirestore.instance
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(casaNumero.toString())
        .update({
          'codigoCasa': codigo,
          'codigoExpira': Timestamp.fromDate(fechaExpiracion),
          'codigoUsos': usos,
        });
    
    return {
      'codigo': codigo,
      'expira': fechaExpiracion,
      'usosDisponibles': usos,
    };
  }
  
  /// Verifica si un código es válido
  static Future<bool> verificarCodigo({
    required String codigo,
    required String condominioId,
    required int casaNumero,
  }) async {
    // Buscar condominio ignorando mayúsculas/minúsculas
    DocumentReference<Map<String, dynamic>>? condoRef;
    final inputCondo = condominioId.trim();
    final direct = await FirebaseFirestore.instance.collection('condominios').doc(inputCondo).get();
    if (direct.exists) {
      condoRef = direct.reference;
    } else {
      final todos = await FirebaseFirestore.instance.collection('condominios').get();
      for (final d in todos.docs) {
        final idLower = d.id.toLowerCase();
        final nombreLower = (d.data()['nombre'] ?? '').toString().toLowerCase();
        if (idLower == inputCondo.toLowerCase() || nombreLower == inputCondo.toLowerCase()) {
          condoRef = d.reference;
          break;
        }
      }
    }
    if (condoRef == null) return false;

    // Intentar doc de casa como string y como número
    DocumentSnapshot<Map<String, dynamic>> doc =
        await condoRef.collection('casas').doc(casaNumero.toString()).get();
    if (!doc.exists) {
      doc = await condoRef.collection('casas').doc(casaNumero.toString().padLeft(3, '0')).get();
    }
    
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final codigoCasa = data['codigoCasa']?.toString();
    final expira = data['codigoExpira'] as Timestamp?;
    final usos = data['codigoUsos'] as int?;
    
    // Debe existir código y coincidir
    if (codigoCasa == null || codigo != codigoCasa) return false;

    // Si existe fecha de expiración, validar que no haya vencido
    if (expira != null && DateTime.now().isAfter(expira.toDate())) {
      return false;
    }

    // Si existe contador de usos, validar y actualizar
    if (usos != null) {
      if (usos <= 0) return false;
      final usosRestantes = usos - 1;

      if (usosRestantes == 0) {
        // Regenerar nuevo código manteniendo o asignando expiración
        final duracionRestante = expira != null
            ? expira.toDate().difference(DateTime.now())
            : const Duration(hours: 24);
        final nuevoCodigo = _crearCodigo();
        final nuevaExp = DateTime.now().add(duracionRestante.isNegative ? const Duration(hours: 24) : duracionRestante);

        await doc.reference.update({
          'codigoCasa': nuevoCodigo,
          'codigoExpira': Timestamp.fromDate(nuevaExp),
          'codigoUsos': 1,
        });
      } else {
        await doc.reference.update({'codigoUsos': usosRestantes});
      }
    }

    // Si no hay contador de usos simplemente es válido
    
    return true;
  }
  
  /// Lee la duración preferida del código para un identificador
  static Future<Duration> _leerDuracionPreferida(String identificador) async {
    final prefs = await SharedPreferences.getInstance();
    final horas = prefs.getInt('duracionHoras_$identificador') ?? 24;
    return Duration(hours: horas);
  }
  
  /// Lee los usos preferidos del código para un identificador
  static Future<int> _leerUsosPreferidos(String identificador) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usos_$identificador') ?? 10;
  }
  
  /// Regenera el código internamente (llamada por el snapshot listener)
  static Future<void> _regenerarCodigoAutomaticamente({
    required String identificador,
    required String condominioId,
    required int casaNumero,
  }) async {
    // Guard: evitar regeneraciones múltiples simultáneas
    if (_regenerando[identificador] == true) return;
    _regenerando[identificador] = true;
    
    try {
      // Leer preferencias del usuario
      final duracion = await _leerDuracionPreferida(identificador);
      final usos = await _leerUsosPreferidos(identificador);
      
      final docRef = FirebaseFirestore.instance
          .collection('condominios')
          .doc(condominioId)
          .collection('casas')
          .doc(casaNumero.toString());
      
      // Usar transacción para evitar condiciones de carrera entre dispositivos
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        final expiraActual = data['codigoExpira'] as Timestamp?;
        final usosActuales = data['codigoUsos'] as int?;
        
        // Validar si realmente necesita regeneración
        final ahora = DateTime.now();
        bool necesitaRegenerar = false;
        
        if (expiraActual != null && ahora.isAfter(expiraActual.toDate())) {
          necesitaRegenerar = true;
        }
        
        if (usosActuales != null && usosActuales <= 0) {
          necesitaRegenerar = true;
        }
        
        // Si otro dispositivo ya regeneró, abortar silenciosamente
        if (!necesitaRegenerar) return;
        
        // Generar nuevo código
        final nuevoCodigo = _crearCodigo();
        final nuevaExpiracion = ahora.add(duracion);
        
        // Actualizar Firestore
        transaction.update(docRef, {
          'codigoCasa': nuevoCodigo,
          'codigoExpira': Timestamp.fromDate(nuevaExpiracion),
          'codigoUsos': usos,
        });
        
        // Actualizar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('codigo_$identificador', nuevoCodigo);
        await prefs.setString('fecha_$identificador', ahora.toIso8601String());
        await prefs.setString('expira_$identificador', nuevaExpiracion.toIso8601String());
        await prefs.setInt('usos_$identificador', usos);
      });
    } finally {
      _regenerando[identificador] = false;
    }
  }
  
  /// Inicia el listener de auto-renovación del código
  /// Retorna el StreamSubscription para que pueda ser cancelado en dispose()
  static StreamSubscription<DocumentSnapshot> iniciarAutoRenovacionCodigo({
    required String identificador,
    required String condominioId,
    required int casaNumero,
  }) {
    final docRef = FirebaseFirestore.instance
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(casaNumero.toString());
    
    return docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      final expira = data['codigoExpira'] as Timestamp?;
      final usos = data['codigoUsos'] as int?;
      
      // Debounce: cancelar timer anterior si existe
      _debounceTimers[identificador]?.cancel();
      
      // Crear nuevo timer con debounce de 1.5 segundos
      _debounceTimers[identificador] = Timer(const Duration(milliseconds: 1500), () {
        final ahora = DateTime.now();
        bool necesitaRegenerar = false;
        
        // Verificar si expiró por tiempo
        if (expira != null && ahora.isAfter(expira.toDate())) {
          necesitaRegenerar = true;
        }
        
        // Verificar si se agotaron los usos
        if (usos != null && usos <= 0) {
          necesitaRegenerar = true;
        }
        
        // Regenerar si es necesario
        if (necesitaRegenerar) {
          _regenerarCodigoAutomaticamente(
            identificador: identificador,
            condominioId: condominioId,
            casaNumero: casaNumero,
          );
        }
      });
    });
  }
}
