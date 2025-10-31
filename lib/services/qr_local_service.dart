import 'dart:convert';
import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import '../models/qr_local_model.dart';
import '../models/propietario_model.dart';

class QrLocalService {
  static const _storageKey = 'qrs_local';

  static Future<List<QrLocalModel>> _readList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => QrLocalModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> _writeList(List<QrLocalModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  static Future<void> save(QrLocalModel qr) async {
    final list = await _readList();
    // Evita duplicados por código
    list.removeWhere((element) => element.codigo == qr.codigo);
    list.add(qr);
    await _writeList(list);
    dev.log('QR guardado para propietario: ${qr.propietarioNombre}', name: 'QrLocalService');
  }

  static Future<List<QrLocalModel>> listAll({bool removeExpired = true}) async {
    var list = await _readList();
    
    // Obtener usuario actual (propietario o visitante)
    final usuarioActual = await _getUsuarioActual();
    if (usuarioActual == null) {
      dev.log('No hay usuario logueado', name: 'QrLocalService');
      return [];
    }
    
    // Filtrar por usuario actual
    list = list.where((qr) {
      // Compatibilidad: si no tiene propietarioId, verificar por condominio y casa
      if (qr.propietarioId != null) {
        return qr.propietarioId == usuarioActual['id'];
      } else {
        // Compatibilidad con QRs antiguos (solo para propietarios)
        if (usuarioActual['tipo'] == 'propietario') {
          return qr.condominio == usuarioActual['condominio'] && 
                 qr.casa == usuarioActual['casa'];
        }
        return false; // Los visitantes necesitan propietarioId
      }
    }).toList();
    
    if (removeExpired) {
      final now = DateTime.now();
      final originalCount = list.length;
      list = list.where((q) => q.expira.isAfter(now) && q.usosRestantes > 0).toList();
      
      if (originalCount != list.length) {
        dev.log('Eliminados ${originalCount - list.length} QRs expirados', name: 'QrLocalService');
        // Solo reescribir si se eliminaron QRs
        final allList = await _readList();
        final filteredAll = allList.where((q) => q.expira.isAfter(now) && q.usosRestantes > 0).toList();
        await _writeList(filteredAll);
      }
    }
    
    dev.log('QRs encontrados para ${usuarioActual['nombre']}: ${list.length}', name: 'QrLocalService');
    return list;
  }

  static Future<void> updateUsos(String codigo, int nuevosUsos) async {
    final list = await _readList();
    for (final qr in list) {
      if (qr.codigo == codigo) {
        final idx = list.indexOf(qr);
        list[idx] = QrLocalModel(
          codigo: qr.codigo,
          condominio: qr.condominio,
          casa: qr.casa,
          expira: qr.expira,
          usosRestantes: nuevosUsos,
          propietarioId: qr.propietarioId,
          propietarioNombre: qr.propietarioNombre,
        );
        break;
      }
    }
    await _writeList(list);
  }
  
  /// Obtiene el usuario actualmente logueado (propietario o visitante)
  static Future<Map<String, dynamic>?> _getUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verificar si hay un propietario logueado
      final propietarioJson = prefs.getString('propietario');
      if (propietarioJson != null) {
        final propietario = PropietarioModel.fromJson(jsonDecode(propietarioJson));
        return {
          'tipo': 'propietario',
          'id': '${propietario.condominio}_${propietario.casa.numero}',
          'nombre': propietario.personas.isNotEmpty ? propietario.personas.first : 'Propietario',
          'condominio': propietario.condominio,
          'casa': propietario.casa.numero,
        };
      }
      
      // Verificar si hay un visitante logueado
      final visitanteNombre = prefs.getString('visitante_nombre');
      final visitanteCi = prefs.getString('visitante_ci');
      if (visitanteNombre != null && visitanteCi != null) {
        return {
          'tipo': 'visitante',
          'id': 'visitante_$visitanteCi',
          'nombre': visitanteNombre,
          'ci': visitanteCi,
        };
      }
      
      return null;
    } catch (e) {
      dev.log('Error obteniendo usuario actual: $e', name: 'QrLocalService');
      return null;
    }
  }
  
}
