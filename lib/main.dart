import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

// Asegúrate de tener los archivos de configuración de Firebase en las carpetas android/ios/web correspondientes.
import 'app.dart';
import 'services/notificacion_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Inicializar datos de localización para intl (evita LocaleDataException)
  await initializeDateFormatting('es_ES', null);
  await FirebaseMessaging.instance.requestPermission();
  // Inicializar servicio de notificaciones
  await NotificacionService.inicializar();
  runApp(const FortGuards());
}
