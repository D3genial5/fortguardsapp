import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Conecta los SDK de Firebase a los puertos del emulador suite local
/// si se compila con `--dart-define=USE_EMULATOR=true`.
///
/// El host por defecto es `10.0.2.2` (Android emulator alias para localhost
/// del host). Para iOS Simulator o web es `localhost`.
class FirebaseEmulator {
  static const bool _useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: false);

  static bool get isActive => kDebugMode && _useEmulator;

  static Future<void> wireUp() async {
    if (!isActive) return;
    final host = _emulatorHost();
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5001);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    debugPrint('🔧 Firebase emulator wired up at $host');
  }

  static String _emulatorHost() {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
    return 'localhost';
  }
}
