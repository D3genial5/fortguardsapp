import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as dev;

import '../models/notificacion_model.dart';

class NotificacionService {
  static final _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  
  /// Obtener el token FCM actual
  static String? get fcmToken => _fcmToken;
  
  // Inicializar el servicio de notificaciones
  static Future<void> inicializar() async {
    try {
      // Solicitar permisos de notificación (requerido en Android 13+)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      dev.log('📱 Permiso de notificaciones: ${settings.authorizationStatus}', name: 'NotificacionService');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Obtener y guardar el token FCM
        _fcmToken = await messaging.getToken();
        dev.log('🔑 FCM Token: $_fcmToken', name: 'NotificacionService');
        
        // Escuchar cambios de token
        messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          dev.log('🔄 FCM Token actualizado: $newToken', name: 'NotificacionService');
        });
      }
      
      // Configurar notificaciones locales
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(initSettings);
      
      // Crear canal de notificación para Android (requerido para Android 8+)
      const androidChannel = AndroidNotificationChannel(
        'fortguards_channel',
        'FortGuards Notificaciones',
        description: 'Notificaciones de acceso y alertas',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      
      // Configurar manejadores de mensajes
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      dev.log('✅ Servicio de notificaciones inicializado', name: 'NotificacionService');
    } catch (e) {
      dev.log('❌ Error al inicializar notificaciones: $e', name: 'NotificacionService');
    }
  }
  
  /// Guardar token FCM en Firestore para un usuario específico
  static Future<void> guardarTokenUsuario({
    required String condominio,
    required int casaNumero,
  }) async {
    if (_fcmToken == null) return;
    
    try {
      await _db
          .collection('condominios')
          .doc(condominio)
          .collection('casas')
          .doc(casaNumero.toString())
          .update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdated': FieldValue.serverTimestamp(),
      });
      dev.log('✅ Token FCM guardado para casa $casaNumero', name: 'NotificacionService');
    } catch (e) {
      dev.log('⚠️ Error guardando token FCM: $e', name: 'NotificacionService');
    }
  }
  
  /// Suscribirse a tópicos FCM para recibir notificaciones push
  static Future<void> suscribirseATopicos({
    required String condominio,
    required int casaNumero,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Suscribirse al tópico del condominio (notificaciones generales)
      await messaging.subscribeToTopic('condo_$condominio');
      dev.log('✅ Suscrito a tópico: condo_$condominio', name: 'NotificacionService');
      
      // Suscribirse al tópico específico de la casa
      await messaging.subscribeToTopic('prop_${condominio}_$casaNumero');
      dev.log('✅ Suscrito a tópico: prop_${condominio}_$casaNumero', name: 'NotificacionService');
      
    } catch (e) {
      dev.log('⚠️ Error suscribiéndose a tópicos: $e', name: 'NotificacionService');
    }
  }
  
  /// Desuscribirse de tópicos FCM (al cerrar sesión)
  static Future<void> desuscribirseDeTopicos({
    required String condominio,
    required int casaNumero,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      await messaging.unsubscribeFromTopic('condo_$condominio');
      await messaging.unsubscribeFromTopic('prop_${condominio}_$casaNumero');
      
      dev.log('✅ Desuscrito de tópicos de $condominio', name: 'NotificacionService');
    } catch (e) {
      dev.log('⚠️ Error desuscribiéndose de tópicos: $e', name: 'NotificacionService');
    }
  }
  
  /// Mostrar una notificación local directamente
  static Future<void> mostrarNotificacion({
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'fortguards_channel',
        'FortGuards Notificaciones',
        channelDescription: 'Notificaciones de acceso y alertas',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        titulo,
        cuerpo,
        details,
        payload: payload,
      );
    } catch (e) {
      dev.log('❌ Error mostrando notificación: $e', name: 'NotificacionService');
    }
  }
  
  // Manejar mensajes en primer plano
  static void _handleForegroundMessage(RemoteMessage message) {
    dev.log('📱 Mensaje recibido en primer plano: ${message.notification?.title}', name: 'NotificacionService');
    _mostrarNotificacionLocal(message);
  }
  
  // Manejar cuando la app se abre desde una notificación
  static void _handleMessageOpenedApp(RemoteMessage message) {
    dev.log('🔓 App abierta desde notificación: ${message.notification?.title}', name: 'NotificacionService');
  }
  
  // Mostrar notificación local
  static Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'propietario_channel',
        'Notificaciones Propietario',
        channelDescription: 'Notificaciones para propietarios',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Nueva notificación',
        message.notification?.body ?? '',
        details,
        payload: message.data.toString(),
      );
    } catch (e) {
      dev.log('❌ Error al mostrar notificación local: $e', name: 'NotificacionService');
    }
  }

  static Stream<List<NotificacionModel>> streamNotificaciones({
    required String condominioId,
    required int casaNumero,
  }) {
    return _db
        .collection('notificaciones')
        .where('condominio', isEqualTo: condominioId)
        .where('casaNumero', isEqualTo: casaNumero)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificacionModel.fromDoc(d.id, d.data()))
            .toList());
  }

  static Stream<List<NotificacionModel>> streamNotificacionesCondominio({
    required String condominioId,
  }) {
    return _db
        .collection('notificaciones')
        .where('condominio', isEqualTo: condominioId)
        .where('tipo', isEqualTo: 'condominio')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificacionModel.fromDoc(d.id, d.data()))
            .toList());
  }

  static Future<void> marcarVisto(String id) async {
    await _db.collection('notificaciones').doc(id).update({'visto': true});
  }
  
  // ============ LISTENER PARA PUSH NOTIFICATIONS EN TIEMPO REAL ============
  
  static StreamSubscription? _notificacionesSubscription;
  static final Set<String> _notificacionesMostradas = {};
  
  /// Iniciar escucha de notificaciones nuevas para mostrar como push
  static void escucharNotificaciones({
    required String condominioId,
    int? casaNumero,
  }) {
    // Cancelar suscripción anterior si existe
    _notificacionesSubscription?.cancel();
    _notificacionesMostradas.clear();
    
    dev.log('🔔 Iniciando escucha de notificaciones para $condominioId', name: 'NotificacionService');
    var esPrimerSnapshot = true;
    
    // Escuchar notificaciones del condominio (tipo: 'condominio' o casaNumero: 0)
    _notificacionesSubscription = _db
        .collection('notificaciones')
        .where('condominio', isEqualTo: condominioId)
        .orderBy('fecha', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      // Evita re-disparar notificaciones antiguas cada vez que se reabre la pantalla
      // o se reinicia el listener. Solo se notifican documentos realmente nuevos.
      if (esPrimerSnapshot) {
        esPrimerSnapshot = false;
        for (final doc in snapshot.docs) {
          _notificacionesMostradas.add(doc.id);
        }
        return;
      }

      for (final change in snapshot.docChanges) {
        // Solo mostrar notificaciones nuevas (added)
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          
          final docId = change.doc.id;
          
          // Evitar mostrar la misma notificación múltiples veces
          if (_notificacionesMostradas.contains(docId)) continue;
          _notificacionesMostradas.add(docId);
          
          // Verificar si es para todo el condominio o para esta casa específica
          final tipo = data['tipo'] as String?;
          final casaNotif = data['casaNumero'] as int?;
          
          final esParaTodos = tipo == 'condominio' || casaNotif == 0 || casaNotif == null;
          final esParaMiCasa = casaNumero != null && casaNotif == casaNumero;
          
          if (esParaTodos || esParaMiCasa) {
            final titulo = data['titulo'] as String? ?? 'Nueva notificación';
            final mensaje = data['mensaje'] as String? ?? '';
            final visto = data['visto'] as bool? ?? false;
            
            // Solo mostrar si no ha sido vista
            if (!visto) {
              dev.log('📬 Nueva notificación: $titulo', name: 'NotificacionService');
              mostrarNotificacion(
                titulo: titulo,
                cuerpo: mensaje,
                payload: docId,
              );
            }
          }
        }
      }
    }, onError: (e) {
      dev.log('❌ Error escuchando notificaciones: $e', name: 'NotificacionService');
    });
  }
  
  /// Detener escucha de notificaciones
  static void detenerEscucha() {
    _notificacionesSubscription?.cancel();
    _notificacionesSubscription = null;
    _notificacionesMostradas.clear();
    dev.log('🔕 Escucha de notificaciones detenida', name: 'NotificacionService');
  }
}
