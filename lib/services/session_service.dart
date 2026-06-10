import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  String? _currentSessionId;
  String? _deviceId;
  
  // Verificar si es el primer uso del dispositivo
  Future<bool> isFirstTimeOnDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey('datosCompletos');
  }
  
  // Marcar datos como completos en este dispositivo
  Future<void> markDataComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('datosCompletos', true);
    await prefs.setString('ultimoAcceso', DateTime.now().toIso8601String());
  }
  
  // Obtener ID único del dispositivo
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      return _deviceId!;
    } catch (e) {
      if (kDebugMode) debugPrint('Error obteniendo device ID: $e');
      _deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return _deviceId!;
    }
  }
  
  // Obtener información del dispositivo
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemVersion': iosInfo.systemVersion,
          'localizedModel': iosInfo.localizedModel,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error obteniendo info del dispositivo: $e');
    }
    
    return {
      'platform': 'Unknown',
      'model': 'Unknown',
    };
  }
  
  // Crear o actualizar sesión
  Future<String?> createOrUpdateSession({
    required String userId,
    required String condominioId,
    required String casaNumero,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final deviceInfo = await getDeviceInfo();

      // Las rules requieren `uid` == auth.uid. Si el propietario está logueado
      // con Custom Token, su uid es `prop_<condo>_<casa>`. Si no hay auth,
      // se persiste solo localmente.
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid == null) {
        // Sin sesión Firebase: persistir solo local.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        await prefs.setString('condominioId', condominioId);
        await prefs.setString('casaNumero', casaNumero);
        return null;
      }

      // Buscar sesión existente para este dispositivo
      final existingSession = await _firestore
          .collection('sesiones')
          .where('deviceId', isEqualTo: deviceId)
          .where('uid', isEqualTo: authUid)
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();

      if (existingSession.docs.isNotEmpty) {
        // Actualizar sesión existente
        final sessionId = existingSession.docs.first.id;
        await _firestore.collection('sesiones').doc(sessionId).update({
          'uid': authUid, // re-afirmar para satisfacer rule
          'ultimoAcceso': FieldValue.serverTimestamp(),
          'deviceInfo': deviceInfo,
        });

        _currentSessionId = sessionId;
        if (kDebugMode) debugPrint('Sesión actualizada: $sessionId');
      } else {
        // Crear nueva sesión
        final sessionDoc = await _firestore.collection('sesiones').add({
          'uid': authUid,
          'userKey': userId,         // mantenemos el ID legacy para compat client
          'condominioId': condominioId,
          'casaNumero': casaNumero,
          'deviceId': deviceId,
          'deviceInfo': deviceInfo,
          'creadoAt': FieldValue.serverTimestamp(),
          'ultimoAcceso': FieldValue.serverTimestamp(),
          'activo': true,
        });

        _currentSessionId = sessionDoc.id;
        if (kDebugMode) debugPrint('Nueva sesión creada: ${sessionDoc.id}');
      }

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (_currentSessionId != null) {
        await prefs.setString('sessionId', _currentSessionId!);
      }
      await prefs.setString('userId', userId);
      await prefs.setString('condominioId', condominioId);
      await prefs.setString('casaNumero', casaNumero);

      return _currentSessionId;
    } catch (e) {
      if (kDebugMode) debugPrint('Error creando/actualizando sesión: $e');
      return null;
    }
  }
  
  // Cerrar sesión actual
  Future<void> closeSession() async {
    try {
      if (_currentSessionId != null) {
        await _firestore.collection('sesiones').doc(_currentSessionId).update({
          'activo': false,
          'cerradoAt': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) debugPrint('Sesión cerrada: $_currentSessionId');
      }
      
      // Limpiar SharedPreferences (excepto datosCompletos)
      final prefs = await SharedPreferences.getInstance();
      final datosCompletos = prefs.getBool('datosCompletos') ?? false;
      
      await prefs.remove('sessionId');
      await prefs.remove('userId');
      await prefs.remove('condominioId');
      await prefs.remove('casaNumero');
      
      // Mantener el flag de datos completos
      if (datosCompletos) {
        await prefs.setBool('datosCompletos', true);
      }
      
      _currentSessionId = null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error cerrando sesión: $e');
    }
  }
  
  // Obtener sesión guardada localmente
  Future<Map<String, dynamic>?> getLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final sessionId = prefs.getString('sessionId');
      final userId = prefs.getString('userId');
      final condominioId = prefs.getString('condominioId');
      // Compat: versiones anteriores guardaban casaNumero como int.
      final casaNumero = prefs.get('casaNumero')?.toString();
      
      if (sessionId != null && userId != null) {
        return {
          'sessionId': sessionId,
          'userId': userId,
          'condominioId': condominioId,
          'casaNumero': casaNumero,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error obteniendo sesión local: $e');
    }
    
    return null;
  }
  
  // Verificar si la sesión está activa
  Future<bool> isSessionActive() async {
    try {
      final localSession = await getLocalSession();
      if (localSession == null) return false;
      
      final sessionDoc = await _firestore
          .collection('sesiones')
          .doc(localSession['sessionId'])
          .get();
      
      if (sessionDoc.exists) {
        final data = sessionDoc.data();
        return data?['activo'] == true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error verificando sesión: $e');
    }
    
    return false;
  }
  
  // Actualizar último acceso
  Future<void> updateLastAccess() async {
    try {
      if (_currentSessionId != null) {
        await _firestore.collection('sesiones').doc(_currentSessionId).update({
          'ultimoAcceso': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error actualizando último acceso: $e');
    }
  }
  
  // Obtener todas las sesiones activas del usuario
  Stream<QuerySnapshot> getUserSessions(String userId) {
    return _firestore
        .collection('sesiones')
        .where('uid', isEqualTo: userId)
        .where('activo', isEqualTo: true)
        .orderBy('ultimoAcceso', descending: true)
        .snapshots();
  }
  
  // Cerrar sesión remota (desde otro dispositivo)
  Future<void> closeRemoteSession(String sessionId) async {
    try {
      await _firestore.collection('sesiones').doc(sessionId).update({
        'activo': false,
        'cerradoRemotamente': true,
        'cerradoAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) debugPrint('Sesión remota cerrada: $sessionId');
    } catch (e) {
      if (kDebugMode) debugPrint('Error cerrando sesión remota: $e');
    }
  }
}
