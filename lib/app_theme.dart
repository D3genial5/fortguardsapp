import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Paleta de colores - Tema Claro
  static const _turquoise = Color(0xFF47D9B2);       // Color principal
  static const _darkTurquoise = Color(0xFF35B092);   // Variante más oscura
  static const _lightTurquoise = Color(0xFF5FE5C4);  // Variante más clara
  static const _background = Color(0xFFF5F5F5);      // Fondo gris muy claro
  static const _surface = Color(0xFFFFFFFF);         // Cards blancas
  static const _textPrimary = Color(0xFF1A1A1A);     // Texto negro/gris oscuro
  static const _textSecondary = Color(0xFF666666);   // Texto secundario gris
  static const _dividerColor = Color(0xFFE0E0E0);    // Bordes y divisores

  static const _radius = 12.0;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _turquoise,
      onPrimary: Colors.white,
      primaryContainer: _lightTurquoise,
      onPrimaryContainer: _textPrimary,
      secondary: _turquoise,
      onSecondary: Colors.white,
      secondaryContainer: _lightTurquoise,
      onSecondaryContainer: _textPrimary,
      tertiary: _darkTurquoise,
      onTertiary: Colors.white,
      tertiaryContainer: _turquoise,
      onTertiaryContainer: Colors.white,
      error: Color(0xFFF44336),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: _surface,
      onSurface: _textPrimary,
      surfaceContainerHighest: Color(0xFFFAFAFA),
      onSurfaceVariant: _textSecondary,
      outline: _dividerColor,
      outlineVariant: Color(0xFFBDBDBD),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: _textPrimary,
      onInverseSurface: _surface,
      inversePrimary: _turquoise,
      surfaceTint: _turquoise,
    ),
    scaffoldBackgroundColor: _background,
    appBarTheme: const AppBarTheme(
      backgroundColor: _turquoise,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardTheme(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: _surface,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _turquoise,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: _turquoise.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _turquoise,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _turquoise,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: _turquoise, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      hintStyle: const TextStyle(color: _textSecondary),
      labelStyle: const TextStyle(color: _textSecondary),
      floatingLabelStyle: const TextStyle(color: _turquoise),
      prefixIconColor: _textSecondary,
      suffixIconColor: _textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _dividerColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: _turquoise, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFF44336), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: Color(0xFFF44336), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    iconTheme: const IconThemeData(
      color: _textSecondary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _turquoise,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _turquoise;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: _turquoise, width: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _turquoise;
        return const Color(0xFFBDBDBD);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _turquoise.withValues(alpha: 0.3);
        return const Color(0xFFE0E0E0);
      }),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: _turquoise,
      textColor: _textPrimary,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(color: _textPrimary, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: _dividerColor,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: _textPrimary),
      bodyMedium: TextStyle(color: _textPrimary),
      bodySmall: TextStyle(color: _textSecondary),
      labelLarge: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: _textSecondary),
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
