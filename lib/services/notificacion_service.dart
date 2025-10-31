import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as dev;

import '../models/notificacion_model.dart';

class NotificacionService {
  static final _db = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Inicializar el servicio de notificaciones
  static Future<void> inicializar() async {
    try {
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
      
      // Configurar manejadores de mensajes
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      dev.log('✅ Servicio de notificaciones inicializado', name: 'NotificacionService');
    } catch (e) {
      dev.log('❌ Error al inicializar notificaciones: $e', name: 'NotificacionService');
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
}
