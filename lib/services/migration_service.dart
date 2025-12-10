import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para migrar datos viejos de access_requests
/// Agrega campos faltantes: tipoAcceso, usosRestantes, codigoQr, fechaAprobacion
class MigrationService {
  static final _firestore = FirebaseFirestore.instance;
  
  /// Genera un código QR único de 8 caracteres
  static String _generarCodigoQr() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }
  
  /// Migra todos los documentos de access_requests que les faltan campos
  /// Retorna un Map con estadísticas de la migración
  static Future<Map<String, int>> migrarAccessRequests() async {
    int total = 0;
    int migrados = 0;
    int yaActualizados = 0;
    int errores = 0;
    
    try {
      // Obtener todos los documentos aceptados
      final query = await _firestore
          .collection('access_requests')
          .where('estado', isEqualTo: 'aceptada')
          .get();
      
      total = query.docs.length;
      
      for (final doc in query.docs) {
        try {
          final data = doc.data();
          
          // Verificar si ya tiene los campos nuevos
          final tieneTipoAcceso = data.containsKey('tipoAcceso') && data['tipoAcceso'] != null;
          final tieneUsosRestantes = data.containsKey('usosRestantes') && data['usosRestantes'] != null;
          final tieneCodigoQr = data.containsKey('codigoQr') && data['codigoQr'] != null;
          
          // Si ya tiene todos los campos, no necesita migración
          if (tieneTipoAcceso && tieneUsosRestantes && tieneCodigoQr) {
            yaActualizados++;
            continue;
          }
          
          // Preparar datos de actualización
          final Map<String, dynamic> updateData = {};
          
          // Determinar tipo de acceso
          if (!tieneTipoAcceso) {
            final codigoUsos = data['codigoUsos'] as int?;
            final fechaExp = data['fechaExpiracion'];
            
            if (codigoUsos != null && codigoUsos >= 999999) {
              updateData['tipoAcceso'] = 'indefinido';
            } else if (fechaExp != null) {
              updateData['tipoAcceso'] = 'tiempo';
            } else {
              updateData['tipoAcceso'] = 'usos';
            }
          }
          
          // Establecer usosRestantes
          if (!tieneUsosRestantes) {
            final codigoUsos = data['codigoUsos'] as int?;
            updateData['usosRestantes'] = codigoUsos ?? 1;
          }
          
          // Generar código QR si no existe
          if (!tieneCodigoQr) {
            updateData['codigoQr'] = _generarCodigoQr();
          }
          
          // Agregar fecha de aprobación si no existe
          if (!data.containsKey('fechaAprobacion') || data['fechaAprobacion'] == null) {
            // Usar la fecha del documento o la fecha actual
            final fecha = data['fecha'];
            if (fecha is Timestamp) {
              updateData['fechaAprobacion'] = fecha;
            } else {
              updateData['fechaAprobacion'] = FieldValue.serverTimestamp();
            }
          }
          
          // Solo actualizar si hay cambios
          if (updateData.isNotEmpty) {
            await _firestore
                .collection('access_requests')
                .doc(doc.id)
                .update(updateData);
            migrados++;
          } else {
            yaActualizados++;
          }
          
        } catch (e) {
          errores++;
          print('Error migrando doc ${doc.id}: $e');
        }
      }
      
    } catch (e) {
      print('Error en migración: $e');
    }
    
    return {
      'total': total,
      'migrados': migrados,
      'yaActualizados': yaActualizados,
      'errores': errores,
    };
  }
  
  /// Verifica el estado de los documentos (sin modificar)
  static Future<Map<String, int>> verificarEstado() async {
    int total = 0;
    int completos = 0;
    int incompletos = 0;
    
    try {
      final query = await _firestore
          .collection('access_requests')
          .where('estado', isEqualTo: 'aceptada')
          .get();
      
      total = query.docs.length;
      
      for (final doc in query.docs) {
        final data = doc.data();
        
        final tieneTipoAcceso = data.containsKey('tipoAcceso') && data['tipoAcceso'] != null;
        final tieneUsosRestantes = data.containsKey('usosRestantes') && data['usosRestantes'] != null;
        final tieneCodigoQr = data.containsKey('codigoQr') && data['codigoQr'] != null;
        
        if (tieneTipoAcceso && tieneUsosRestantes && tieneCodigoQr) {
          completos++;
        } else {
          incompletos++;
          print('Doc incompleto: ${doc.id}');
          print('  tipoAcceso: ${data['tipoAcceso']}');
          print('  usosRestantes: ${data['usosRestantes']}');
          print('  codigoQr: ${data['codigoQr']}');
        }
      }
      
    } catch (e) {
      print('Error verificando: $e');
    }
    
    return {
      'total': total,
      'completos': completos,
      'incompletos': incompletos,
    };
  }
}
