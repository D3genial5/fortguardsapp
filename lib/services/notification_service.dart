import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification_service.dart' show globalNavigatorKey;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentToken;
  String? _currentUserId;
  
  // Inicializar servicio de notificaciones
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    
    // Configurar listeners de FCM primero (síncrono)
    _configureFCMListeners();
    
    // Escuchar cambios de token
    _fcm.onTokenRefresh.listen(_saveToken);
    
    // Solicitar permisos
    await _requestPermissions();
    
    // Configurar notificaciones locales
    await _configureLocalNotifications();
    
    // Obtener y guardar token FCM
    await _getAndSaveToken();
  }
  
  // Solicitar permisos de notificaciones
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('Permisos de notificación: ${settings.authorizationStatus}');
  }
  
  // Configurar notificaciones locales
  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );
    
    // Crear canal de notificaciones para Android
    const androidChannel = AndroidNotificationChannel(
      'fortguards_channel',
      'FortGuards Notificaciones',
      description: 'Canal principal de notificaciones',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
  
  // Obtener y guardar token FCM
  Future<void> _getAndSaveToken() async {
    try {
      _currentToken = await _fcm.getToken();
      if (_currentToken != null && _currentUserId != null) {
        await _saveToken(_currentToken!);
      }
    } catch (e) {
      debugPrint('Error obteniendo token FCM: $e');
    }
  }
  
  // Guardar token en Firestore
  Future<void> _saveToken(String token) async {
    try {
      if (_currentUserId == null) return;
      
      // Actualizar tokens FCM en credenciales
      await _firestore.collection('credenciales').doc(_currentUserId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'ultimoLoginAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Token FCM guardado: $token');
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }
  
  // Configurar listeners de FCM
  void _configureFCMListeners() {
    // Mensaje en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
    
    // App abierta desde notificación (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationOpen(message);
    });
    
    // Verificar si la app se abrió desde notificación (terminated)
    _checkInitialMessage();
  }
  
  // Manejar mensaje en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Notificación',
        body: notification.body ?? '',
        payload: data['route'] ?? '',
      );
    }
    
    // Guardar notificación en Firestore
    _saveNotificationToFirestore(message);
  }
  
  // Mostrar notificación local
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Obtener preferencias de notificaciones
    final prefs = await SharedPreferences.getInstance();
    final soundEnabled = prefs.getBool('notification_sound') ?? true;
    final vibrationEnabled = prefs.getBool('notification_vibration') ?? true;
    
    final androidDetails = AndroidNotificationDetails(
      'fortguards_channel',
      'FortGuards Notificaciones',
      channelDescription: 'Canal principal de notificaciones',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: soundEnabled,
      enableVibration: vibrationEnabled,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  // Guardar notificación en Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      if (_currentUserId == null) return;
      
      await _firestore.collection('notificaciones').add({
        'titulo': message.notification?.title ?? 'Notificación',
        'cuerpo': message.notification?.body ?? '',
        'data': message.data,
        'to': _currentUserId,
        'tipo': message.data['tipo'] ?? 'privada',
        'leida': false,
        'creadoAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando notificación: $e');
    }
  }
  
  // Manejar apertura de notificación
  void _handleNotificationOpen(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      _navigateToRoute(route);
    }
  }
  
  // Manejar tap en notificación local
  void _handleNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      _navigateToRoute(payload);
    }
  }
  
  // Navegar a ruta específica
  void _navigateToRoute(String route) {
    final navigator = globalNavigatorKey.currentState;
    if (navigator == null) return;
    
    // Implementar navegación según la ruta
    switch (route) {
      case 'expensas':
        navigator.pushNamed('/pago-expensas');
        break;
      case 'reservas':
        navigator.pushNamed('/reservas');
        break;
      case 'notificaciones':
        navigator.pushNamed('/notificaciones');
        break;
      default:
        if (route.isNotEmpty) {
          navigator.pushNamed(route);
        }
    }
  }
  
  // Verificar mensaje inicial (app terminated)
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }
  
  // Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notificaciones').doc(notificationId).update({
        'leida': true,
      });
    } catch (e) {
      debugPrint('Error marcando notificación como leída: $e');
    }
  }
  
  // Suscribirse a topic del condominio
  Future<void> subscribeToCondominio(String condominioId) async {
    try {
      await _fcm.subscribeToTopic('condominio_$condominioId');
      debugPrint('Suscrito al topic: condominio_$condominioId');
    } catch (e) {
      debugPrint('Error suscribiendo a topic: $e');
    }
  }
  
  // Desuscribirse de topic del condominio
  Future<void> unsubscribeFromCondominio(String condominioId) async {
    try {
      await _fcm.unsubscribeFromTopic('condominio_$condominioId');
      debugPrint('Desuscrito del topic: condominio_$condominioId');
    } catch (e) {
      debugPrint('Error desuscribiendo de topic: $e');
    }
  }
  
  // Obtener notificaciones del usuario
  Stream<QuerySnapshot> getUserNotifications() {
    if (_currentUserId == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('notificaciones')
        .where('to', whereIn: [_currentUserId, 'todos'])
        .orderBy('creadoAt', descending: true)
        .snapshots();
  }
  
  // Obtener token actual
  String? get currentToken => _currentToken;
}

// Handler para mensajes en background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Mensaje en background: ${message.messageId}');
  // Aquí se puede procesar el mensaje en background si es necesario
}
