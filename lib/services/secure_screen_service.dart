import 'dart:async';

import 'package:screen_protector/screen_protector.dart';

class SecureScreenService {
  static int _refCount = 0;
  static Completer<void>? _pending;

  static Future<void> enable() {
    _refCount++;
    return _apply();
  }

  static Future<void> disable() {
    if (_refCount > 0) {
      _refCount--;
    }
    return _apply();
  }

  static Future<void> _apply() async {
    if (_pending != null) {
      return _pending!.future;
    }

    _pending = Completer<void>();
    try {
      if (_refCount > 0) {
        await ScreenProtector.preventScreenshotOn();
        await ScreenProtector.protectDataLeakageOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
        await ScreenProtector.protectDataLeakageOff();
      }
      _pending!.complete();
    } catch (e) {
      _pending!.complete();
    } finally {
      _pending = null;
    }
  }
}
