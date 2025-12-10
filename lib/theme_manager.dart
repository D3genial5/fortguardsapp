import 'package:flutter/material.dart';

/// Controls the application's [ThemeMode].
///
/// Use [ThemeManager.toggle] to switch between light and dark themes.
class ThemeManager {
  ThemeManager._();
  
  /// Notifier with current [ThemeMode]. Widgets can listen to rebuild on change.
  static final ValueNotifier<ThemeMode> notifier = ValueNotifier(ThemeMode.light);

  /// Toggle between light and dark modes. If current mode is system, assumes light first.
  static void toggle() {
    switch (notifier.value) {
      case ThemeMode.light:
        notifier.value = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        notifier.value = ThemeMode.light;
        break;
      case ThemeMode.system:
        // If system, start with dark for visibility.
        notifier.value = ThemeMode.dark;
        break;
    }
  }
}
