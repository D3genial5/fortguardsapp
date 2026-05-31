import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Logger único de la app — no emite nada en release.
///
/// Reemplaza a `print`, `debugPrint` y `developer.log`. En release todos los
/// métodos son no-ops. Errores fatales deben reportarse a Crashlytics
/// directamente.
abstract class AppLog {
  static void log(String msg, {String? name, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      dev.log(msg, name: name ?? 'app', error: error, stackTrace: stackTrace);
    }
  }

  static void d(String msg, {String name = 'app'}) => log(msg, name: name);
  static void i(String msg, {String name = 'app'}) => log(msg, name: name);
  static void w(String msg, {String name = 'app', Object? error}) =>
      log(msg, name: name, error: error);
  static void e(String msg, {String name = 'app', Object? error, StackTrace? stackTrace}) =>
      log(msg, name: name, error: error, stackTrace: stackTrace);
}
