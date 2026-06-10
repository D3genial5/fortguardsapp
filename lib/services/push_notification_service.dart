import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// GlobalKey para acceder al Navigator desde servicios
/// Debe asignarse en MaterialApp: navigatorKey: PushNotificationService.navigatorKey
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// Handler para mensajes en background (debe estar fuera de cualquier clase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) debugPrint('📩 Background message: ${message.messageId}');
  
  // Procesar mensaje según tipo
  final data = message.data;
  final type = data['type'] ?? '';
  
  switch (type) {
    case 'qrReady':
      await _showLocalNotification(
        'QR Listo',
        'Tu código QR está listo para usar',
        payload: jsonEncode(data),
      );
      break;
    case 'qrExpired':
      await _showLocalNotification(
        'QR Expirado',
        'Tu código QR ha expirado. Solicita uno nuevo',
        payload: jsonEncode(data),
      );
      break;
    case 'visitorAccepted':
      await _showLocalNotification(
        'Visita en tu casa',
        '${data['visitorName']} ha ingresado a las ${data['time']}',
        payload: jsonEncode(data),
      );
      break;
    case 'requestUpdate':
      final estado = data['estado'] ?? '';
      await _showLocalNotification(
        'Solicitud $estado',
        'Tu solicitud de acceso ha sido $estado',
        payload: jsonEncode(data),
      );
      break;
    case 'condominiumNotice':
      await _showLocalNotification(
        data['title'] ?? 'Aviso del Condominio',
        data['body'] ?? '',
        payload: jsonEncode(data),
      );
      break;
    case 'expenseReminder':
      await _showLocalNotification(
        'Recordatorio de Expensa',
        'Monto pendiente: ${data['amount']}',
        payload: jsonEncode(data),
      );
      break;
  }
}

// Helper para mostrar notificación local desde background
Future<void> _showLocalNotification(String title, String body, {String? payload}) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const androidDetails = AndroidNotificationDetails(
    'fortguards_channel',
    'FortGuards Notifications',
    channelDescription: 'Notificaciones de FortGuards',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
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
  
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: payload,
  );
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _currentRole;
  String? _condominio;
  String? _casaNumero;
  String? _qrCodigo;
  
  // Inicializar servicio completo
  Future<void> initialize({
    required String role,
    String? condominio,
    String? casaNumero,
    String? qrCodigo,
  }) async {
    _currentRole = role;
    _condominio = condominio;
    _casaNumero = casaNumero;
    _qrCodigo = qrCodigo;
    
    // Configurar notificaciones locales
    await _initializeLocalNotifications();
    
    // Solicitar permisos
    await _requestPermissions();
    
    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Configurar listeners para foreground
    _setupForegroundListeners();
    
    // Suscribirse a topics según rol
    await _subscribeToTopics();
    
    // Obtener y guardar token
    await _saveToken();
    
    // Escuchar cambios de token
    _fcm.onTokenRefresh.listen((newToken) async {
      await _updateToken(newToken);
    });
  }
  
  // Configurar notificaciones locales
  Future<void> _initializeLocalNotifications() async {
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
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );
    
    // Crear canal de notificación para Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'fortguards_channel',
        'FortGuards Notifications',
        description: 'Notificaciones de FortGuards',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
  
  // Solicitar permisos
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
    );
    
    if (kDebugMode) debugPrint('📱 Permisos de notificación: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) debugPrint('✅ Usuario autorizó notificaciones');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      if (kDebugMode) debugPrint('⚠️ Usuario autorizó notificaciones provisionales');
    } else {
      if (kDebugMode) debugPrint('❌ Usuario rechazó notificaciones');
    }
  }
  
  // Configurar listeners para mensajes en foreground
  void _setupForegroundListeners() {
    // Mensajes cuando la app está abierta
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('📨 Foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });
    
    // Cuando el usuario toca una notificación y la app se abre
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('📬 Message opened app: ${message.messageId}');
      _handleMessageOpenedApp(message);
    });
    
    // Verificar si la app se abrió desde una notificación
    _checkInitialMessage();
  }
  
  // Manejar mensaje en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;
    
    final data = message.data;
    final type = data['type'] ?? '';
    
    // Mostrar notificación local o snackbar según el tipo
    switch (type) {
      case 'visitorAccepted':
        _showInAppBanner(
          '🏠 ${data['visitorName']} ha ingresado',
          'A las ${data['time']}',
          Colors.green,
        );
        break;
      case 'qrExpired':
        _showInAppBanner(
          '⏰ QR Expirado',
          'Tu código QR ha expirado',
          Colors.orange,
        );
        break;
      case 'requestUpdate':
        final estado = data['estado'] ?? '';
        final color = estado == 'aceptada' ? Colors.green : Colors.red;
        _showInAppBanner(
          estado == 'aceptada' ? '✅ Solicitud Aprobada' : '❌ Solicitud Rechazada',
          'Tu solicitud ha sido $estado',
          color,
        );
        break;
      default:
        // Para otros tipos, mostrar notificación local
        if (message.notification != null) {
          _showLocalNotificationFromRemote(message);
        }
    }
  }
  
  // Mostrar banner in-app no intrusivo
  void _showInAppBanner(String title, String body, Color color) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            // Navegar según el tipo
            _navigateFromNotification(title);
          },
        ),
      ),
    );
  }
  
  // Mostrar notificación local desde mensaje remoto
  Future<void> _showLocalNotificationFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    const androidDetails = AndroidNotificationDetails(
      'fortguards_channel',
      'FortGuards Notifications',
      channelDescription: 'Notificaciones de FortGuards',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
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
      notification.title ?? 'FortGuards',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }
  
  // Manejar cuando se abre la app desde notificación
  void _handleMessageOpenedApp(RemoteMessage message) {
    final navigator = globalNavigatorKey.currentState;
    if (navigator == null) return;
    
    final data = message.data;
    final type = data['type'] ?? '';
    
    switch (type) {
      case 'visitorAccepted':
        navigator.pushNamed('/logs-accesos');
        break;
      case 'qrReady':
        navigator.pushNamed('/mis-qrs-invitados');
        break;
      case 'requestUpdate':
        navigator.pushNamed('/gestionar-solicitudes');
        break;
    }
  }
  
  // Verificar mensaje inicial
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }
  
  // Manejar tap en notificación local
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    final navigator = globalNavigatorKey.currentState;
    if (navigator == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] ?? '';
      
      switch (type) {
        case 'visitorAccepted':
          navigator.pushNamed('/logs-accesos');
          break;
        case 'qrReady':
          navigator.pushNamed('/mis-qrs-invitados');
          break;
        case 'requestUpdate':
          navigator.pushNamed('/gestionar-solicitudes');
          break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error parsing notification payload: $e');
    }
  }
  
  // Navegar desde notificación
  void _navigateFromNotification(String title) {
    final navigator = globalNavigatorKey.currentState;
    if (navigator == null) return;
    
    if (title.contains('Visita')) {
      navigator.pushNamed('/logs-accesos');
    } else if (title.contains('QR')) {
      navigator.pushNamed('/mis-qrs-invitados');
    } else if (title.contains('Solicitud')) {
      navigator.pushNamed('/gestionar-solicitudes');
    }
  }
  
  // Suscribirse a topics según rol
  Future<void> _subscribeToTopics() async {
    // Desuscribirse de todos los topics anteriores
    await _unsubscribeFromAllTopics();
    
    switch (_currentRole) {
      case 'propietario':
        if (_condominio != null) {
          // Topic del condominio para avisos generales
          await _fcm.subscribeToTopic('condo_$_condominio');
          if (kDebugMode) debugPrint('📢 Suscrito a: condo_$_condominio');
          
          if (_casaNumero != null) {
            // Topic específico del propietario
            await _fcm.subscribeToTopic('prop_${_condominio}_$_casaNumero');
            if (kDebugMode) debugPrint('Suscrito a: prop_${_condominio}_$_casaNumero');
          }
        }
        break;
        
      case 'guardia':
        if (_condominio != null) {
          // Topic del condominio para guardias
          await _fcm.subscribeToTopic('guardia_$_condominio');
          if (kDebugMode) debugPrint('📢 Suscrito a: guardia_$_condominio');
        }
        break;
        
      case 'visitante':
        if (_qrCodigo != null) {
          // Topic del QR específico
          await _fcm.subscribeToTopic('qr_$_qrCodigo');
          if (kDebugMode) debugPrint('📢 Suscrito a: qr_$_qrCodigo');
        }
        break;
    }
    
    // Topic global para todos los usuarios
    await _fcm.subscribeToTopic('all_users');
    if (kDebugMode) debugPrint('📢 Suscrito a: all_users');
  }
  
  // Desuscribirse de todos los topics
  Future<void> _unsubscribeFromAllTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final previousTopics = prefs.getStringList('subscribed_topics') ?? [];
    
    for (final topic in previousTopics) {
      await _fcm.unsubscribeFromTopic(topic);
      if (kDebugMode) debugPrint('🔕 Desuscrito de: $topic');
    }
    
    await prefs.remove('subscribed_topics');
  }
  
  // Guardar token FCM
  Future<void> _saveToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _updateToken(token);
    }
  }
  
  // Actualizar token en SharedPreferences y Firestore
  Future<void> _updateToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);

    // Persistir token en Firestore para poder enviar push desde el servidor
    if (_condominio != null && _casaNumero != null && _currentRole == 'propietario') {
      try {
        await FirebaseFirestore.instance
            .collection('condominios')
            .doc(_condominio!)
            .collection('casas')
            .doc(_casaNumero.toString())
            .update({'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()});
      } catch (e) {
        if (kDebugMode) debugPrint('Error guardando FCM token en Firestore: $e');
      }
    }
  }
  
  // Actualizar suscripciones cuando cambia el rol o datos
  Future<void> updateSubscriptions({
    String? role,
    String? condominio,
    String? casaNumero,
    String? qrCodigo,
  }) async {
    _currentRole = role ?? _currentRole;
    _condominio = condominio ?? _condominio;
    _casaNumero = casaNumero ?? _casaNumero;
    _qrCodigo = qrCodigo ?? _qrCodigo;
    
    await _subscribeToTopics();
  }
  
  // Limpiar al cerrar sesión
  Future<void> clearSubscriptions() async {
    await _unsubscribeFromAllTopics();
    _currentRole = null;
    _condominio = null;
    _casaNumero = null;
    _qrCodigo = null;
  }
  
  // Obtener token actual
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
  
  // Verificar si las notificaciones están habilitadas
  Future<bool> areNotificationsEnabled() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
