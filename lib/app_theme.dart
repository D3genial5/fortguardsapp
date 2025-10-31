import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Paleta compartida con admin
  static const _brand = Color(0xFF141561);
  static const _secondary = Color(0xFF18187A);
  static const _tertiary = Color(0xFF5D67C6);
  static const _pearlWhite = Color(0xFFFAFAF8);
  static const _surfaceWhite = Color(0xFFFFFFFF);

  static const _radius = 12.0;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1A1D5E),
      onPrimaryContainer: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A2A8E),
      onSecondaryContainer: Colors.white,
      tertiary: _tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF7A83D4),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: _surfaceWhite,
      onSurface: Color(0xFF1A1C1E),
      surfaceContainerHighest: Color(0xFFF3F3F1),
      onSurfaceVariant: Color(0xFF44474E),
      outline: Color(0xFF75777F),
      outlineVariant: Color(0xFFC5C6D0),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF2F3036),
      onInverseSurface: Color(0xFFF1F0F4),
      inversePrimary: _tertiary,
      surfaceTint: _brand,
    ),
    scaffoldBackgroundColor: _pearlWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: _surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _brand,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _brand, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _brand, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2F3036),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFC6DBF1), // Celeste claro
      onPrimary: Color(0xFF0D1F30), // Azul muy oscuro para texto sobre celeste
      primaryContainer: Color(0xFF1A3A52), // Azul navy inputs
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFFC6DBF1),
      onSecondary: Color(0xFF0D1F30),
      secondaryContainer: Color(0xFF1A3A52),
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFFC6DBF1),
      onTertiary: Color(0xFF0D1F30),
      tertiaryContainer: Color(0xFF1A3A52),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFFF5449),
      onError: Colors.white,
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF000000), // Negro puro
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF1A3A52), // Azul navy para cards
      onSurfaceVariant: Color(0xFFB8C7D6), // Gris azulado claro
      outline: Color(0xFF3A5A72), // Borde sutil azul
      outlineVariant: Color(0xFF2A4A62),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Colors.white,
      onInverseSurface: Color(0xFF000000),
      inversePrimary: Color(0xFF1A3A52),
      surfaceTint: Color(0xFFC6DBF1),
    ),
    scaffoldBackgroundColor: const Color(0xFF000000), // Negro puro
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F2D49), // Azul navy oscuro AppBar
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: const Color(0xFF1A3A52), // Azul navy para cards
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC6DBF1), // Celeste claro
        foregroundColor: const Color(0xFF0D1F30), // Texto azul oscuro
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFC6DBF1), // Celeste claro
        foregroundColor: const Color(0xFF0D1F30), // Texto azul oscuro
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC6DBF1), // Texto celeste
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: Color(0xFFC6DBF1), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A3A52), // Azul navy inputs
      hintStyle: const TextStyle(color: Color(0xFF7A8FA4)), // Hint más claro
      labelStyle: const TextStyle(color: Color(0xFFB8C7D6)), // Label claro
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFC6DBF1), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFFF5449), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFFF5449), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFFC6DBF1); // Celeste cuando activo
        }
        return const Color(0xFF7A8FA4); // Gris cuando inactivo
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF1A3A52); // Track azul navy
        }
        return Colors.white.withValues(alpha: 0.15);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A3A52), // Azul navy
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A4A62), // Divisor sutil
      thickness: 1,
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFB8C7D6), // Íconos claros
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFB8C7D6)),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: Color(0xFFB8C7D6)),
    ),
  );
}
