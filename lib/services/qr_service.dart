import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qr_invitado_model.dart';
import '../models/log_acceso_model.dart';
import 'dart:developer' as dev;

class QrService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionQr = 'qr_invitados';
  static const String _collectionLogs = 'logs_accesos';

  /// Crear un nuevo QR de invitado en Firestore
  static Future<void> crearQrInvitado(QrInvitadoModel qr) async {
    try {
      await _db.collection(_collectionQr).doc(qr.codigo).set(qr.toFirestore());
      dev.log('✅ QR creado: ${qr.codigo}', name: 'QrService');
    } catch (e) {
      dev.log('❌ Error creando QR: $e', name: 'QrService');
      rethrow;
    }
  }

  /// Obtener un QR por su código
  static Future<QrInvitadoModel?> obtenerQr(String codigo) async {
    try {
      final doc = await _db.collection(_collectionQr).doc(codigo).get();
      if (!doc.exists) return null;
      return QrInvitadoModel.fromFirestore(doc);
    } catch (e) {
      dev.log('❌ Error obteniendo QR: $e', name: 'QrService');
      return null;
    }
  }

  /// Actualizar un QR existente
  static Future<void> actualizarQr(QrInvitadoModel qr) async {
    try {
      await _db.collection(_collectionQr).doc(qr.codigo).update(qr.toFirestore());
      dev.log('✅ QR actualizado: ${qr.codigo}', name: 'QrService');
    } catch (e) {
      dev.log('❌ Error actualizando QR: $e', name: 'QrService');
      rethrow;
    }
  }

  /// Revocar un QR (cambia estado a revocado)
  static Future<void> revocarQr(String codigo) async {
    try {
      await _db.collection(_collectionQr).doc(codigo).update({
        'estado': EstadoQr.revocado.name,
      });
      dev.log('✅ QR revocado: $codigo', name: 'QrService');
    } catch (e) {
      dev.log('❌ Error revocando QR: $e', name: 'QrService');
      rethrow;
    }
  }

  /// Decrementar usos de un QR (transacción atómica)
  static Future<bool> decrementarUsos(String codigo) async {
    try {
      final docRef = _db.collection(_collectionQr).doc(codigo);

      return await _db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        final data = snapshot.data()!;
        final usosRestantes = data['usosRestantes'] as int?;

        if (usosRestantes == null || usosRestantes <= 0) {
          // Ya no tiene usos
          transaction.update(docRef, {'estado': EstadoQr.sinUsos.name});
          return false;
        }

        final nuevosUsos = usosRestantes - 1;
        final updates = <String, dynamic>{'usosRestantes': nuevosUsos};

        // Si llega a 0, cambiar estado
        if (nuevosUsos == 0) {
          updates['estado'] = EstadoQr.sinUsos.name;
        }

        transaction.update(docRef, updates);
        dev.log('✅ Usos decrementados: $codigo ($nuevosUsos restantes)', name: 'QrService');
        return true;
      });
    } catch (e) {
      dev.log('❌ Error decrementando usos: $e', name: 'QrService');
      return false;
    }
  }

  /// Obtener todos los QR de un propietario
  static Stream<List<QrInvitadoModel>> obtenerQrsPorPropietario({
    required String condominio,
    required int casaNumero,
  }) {
    return _db
        .collection(_collectionQr)
        .where('condominio', isEqualTo: condominio)
        .where('casaNumero', isEqualTo: casaNumero)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => QrInvitadoModel.fromFirestore(doc)).toList();
    });
  }

  /// Registrar un acceso en los logs
  static Future<void> registrarAcceso(LogAccesoModel log) async {
    try {
      await _db.collection(_collectionLogs).add(log.toFirestore());
      dev.log('✅ Log de acceso registrado: ${log.invitadoNombre}', name: 'QrService');
    } catch (e) {
      dev.log('❌ Error registrando log: $e', name: 'QrService');
      rethrow;
    }
  }

  /// Obtener logs de acceso por condominio
  static Stream<List<LogAccesoModel>> obtenerLogsPorCondominio(String condominio) {
    return _db
        .collection(_collectionLogs)
        .where('condominio', isEqualTo: condominio)
        .orderBy('fecha', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogAccesoModel.fromFirestore(doc)).toList();
    });
  }

  /// Validar un QR escaneado (para guardias)
  static Future<Map<String, dynamic>> validarQr({
    required String codigo,
    required String condominioGuardia,
  }) async {
    try {
      final qr = await obtenerQr(codigo);

      if (qr == null) {
        return {
          'valido': false,
          'mensaje': 'QR no encontrado en el sistema',
          'resultado': ResultadoAcceso.qrInvalido,
        };
      }

      // Verificar que el QR pertenece al condominio del guardia
      if (qr.condominio != condominioGuardia) {
        return {
          'valido': false,
          'mensaje': 'Este QR no pertenece a este condominio',
          'resultado': ResultadoAcceso.qrInvalido,
          'qr': qr,
        };
      }

      // Verificar estado
      if (qr.estado == EstadoQr.revocado) {
        return {
          'valido': false,
          'mensaje': 'QR revocado por el propietario',
          'resultado': ResultadoAcceso.qrInvalido,
          'qr': qr,
        };
      }

      // Verificar expiración por fecha
      if (qr.expira != null && DateTime.now().isAfter(qr.expira!)) {
        return {
          'valido': false,
          'mensaje': 'QR expirado por tiempo',
          'resultado': ResultadoAcceso.expirado,
          'qr': qr,
        };
      }

      // Verificar usos restantes
      if (qr.usosRestantes != null && qr.usosRestantes! <= 0) {
        return {
          'valido': false,
          'mensaje': 'QR sin usos restantes',
          'resultado': ResultadoAcceso.sinUsos,
          'qr': qr,
        };
      }

      return {
        'valido': true,
        'mensaje': 'QR válido',
        'resultado': ResultadoAcceso.aceptado,
        'qr': qr,
      };
    } catch (e) {
      dev.log('❌ Error validando QR: $e', name: 'QrService');
      return {
        'valido': false,
        'mensaje': 'Error al validar QR: $e',
        'resultado': ResultadoAcceso.qrInvalido,
      };
    }
  }

  /// Procesar acceso completo (validar + decrementar + registrar log)
  static Future<Map<String, dynamic>> procesarAcceso({
    required String codigo,
    required String guardiaId,
    required String guardiaNombre,
    required String condominioGuardia,
    bool aceptado = true,
    String? observaciones,
  }) async {
    try {
      // Validar QR
      final validacion = await validarQr(
        codigo: codigo,
        condominioGuardia: condominioGuardia,
      );

      final qr = validacion['qr'] as QrInvitadoModel?;
      ResultadoAcceso resultado = validacion['resultado'];

      // Si es válido y se acepta, decrementar usos
      if (validacion['valido'] == true && aceptado && qr != null) {
        if (qr.usosRestantes != null) {
          final decrementado = await decrementarUsos(codigo);
          if (!decrementado) {
            resultado = ResultadoAcceso.sinUsos;
          }
        }
      } else if (!aceptado) {
        resultado = ResultadoAcceso.denegado;
      }

      // Registrar log si tenemos datos del QR
      if (qr != null) {
        final log = LogAccesoModel(
          qrCodigo: codigo,
          guardiaId: guardiaId,
          guardiaNombre: guardiaNombre,
          condominio: qr.condominio,
          casaNumero: qr.casaNumero,
          invitadoNombre: qr.invitadoNombre,
          invitadoCi: qr.invitadoCi,
          placaVehiculo: qr.placaVehiculo,
          fecha: DateTime.now(),
          resultado: resultado,
          observaciones: observaciones,
        );
        await registrarAcceso(log);
      }

      return validacion;
    } catch (e) {
      dev.log('❌ Error procesando acceso: $e', name: 'QrService');
      return {
        'valido': false,
        'mensaje': 'Error procesando acceso: $e',
        'resultado': ResultadoAcceso.qrInvalido,
      };
    }
  }
}
