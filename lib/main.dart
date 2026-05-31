import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notificacion_service.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase error: $e');
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
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
