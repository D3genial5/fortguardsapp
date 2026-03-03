import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notificacion_service.dart';

Future<void> main() async {
  // Paso 1: Binding
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Step 1: Flutter binding initialized');
  
  // Paso 2: Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Step 2: Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase error: $e');
    // Continuar sin Firebase
  }
  
  // Paso 3: Localización
  try {
    await initializeDateFormatting('es_ES', null);
    debugPrint('✅ Step 3: Date formatting initialized');
  } catch (e) {
    debugPrint('❌ Date formatting error: $e');
  }
  
  // Paso 4: Notificaciones push
  try {
    await NotificacionService.inicializar();
    debugPrint('✅ Step 4: Push notifications initialized');
  } catch (e) {
    debugPrint('❌ Push notifications error: $e');
  }
  
  debugPrint('🚀 Starting app...');
  runApp(const FortGuards());
}
