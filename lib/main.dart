import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/firebase_emulator.dart';
import 'core/app_log.dart';
import 'services/notificacion_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseEmulator.wireUp();

      // Crashlytics no funciona en web — guardear init
      if (!kIsWeb) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase error: $e');
    }

    // Auth anónimo para visitantes — habilita escribir visitantes/
    // y access_requests/ con auth.uid presente. Si ya hay user (propietario
    // re-abriendo la app), no toca nada.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        if (kDebugMode) {
          AppLog.log('🟢 Anon auth OK uid=${FirebaseAuth.instance.currentUser?.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) AppLog.log('🔴 Anon auth falló: $e');
    }

    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e) {
      if (kDebugMode) debugPrint('Date formatting error: $e');
    }

    try {
      await NotificacionService.inicializar();
    } catch (e) {
      if (kDebugMode) debugPrint('Push notifications error: $e');
    }

    runApp(const FortGuards());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}
