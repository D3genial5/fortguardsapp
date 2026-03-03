import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════
  // BRANDBOOK FORTGUARD - Paleta oficial
  // ═══════════════════════════════════════════════════════════
  static const _primary = Color(0xFFFF4200);         // Naranja FortGuard
  static const _primaryLight = Color(0xFFFF6B35);    // Naranja claro (hover/pressed)
  static const _black = Color(0xFF000000);           // Negro sólido
  static const _beige = Color(0xFFF6EEE3);           // Beige claro (fondo neutro)

  // Fondos
  static const _background = _beige;                 // Fondo general beige brandbook
  static const _surface = Color(0xFFFFFFFF);         // Blanco puro para cards
  static const _surfaceSecondary = Color(0xFFF9F4ED); // Beige más claro

  // Textos
  static const _textPrimary = _black;                // Negro sólido
  static const _textSecondary = Color(0xFF5A5A5A);   // Gris oscuro
  static const _textMuted = Color(0xFF8A8A8A);       // Gris medio

  // Bordes y divisores
  static const _dividerColor = Color(0xFFE0D8CE);    // Beige borde

  // Tipografías Brandbook
  static const _fontPrimary = 'Poppins';             // Títulos y UI
  static const _fontSecondary = 'LexendDeca';        // Cuerpo de texto

  // ═══════════════════════════════════════════════════════════
  // TEMA PRINCIPAL
  // ═══════════════════════════════════════════════════════════
  static final theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _fontSecondary,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: _primaryLight,
      onPrimaryContainer: Colors.white,
      secondary: _black,
      onSecondary: Colors.white,
      secondaryContainer: _surfaceSecondary,
      onSecondaryContainer: _textPrimary,
      tertiary: _primary,
      onTertiary: Colors.white,
      tertiaryContainer: _primaryLight,
      onTertiaryContainer: Colors.white,
      error: Color(0xFFD32F2F),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: _surface,
      onSurface: _textPrimary,
      surfaceContainerHighest: _surfaceSecondary,
      onSurfaceVariant: _textSecondary,
      outline: _dividerColor,
      outlineVariant: Color(0xFFF0E8DD),
      shadow: Color(0x1A000000),
      scrim: Colors.black,
      inverseSurface: _black,
      onInverseSurface: Colors.white,
      inversePrimary: _primaryLight,
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: _background,

    // AppBar - Negro sólido brandbook
    appBarTheme: const AppBarTheme(
      backgroundColor: _black,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: _primary),
      titleTextStyle: TextStyle(
        fontFamily: _fontPrimary,
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),

    // Cards
    cardTheme: CardTheme(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    // Elevated Button - Naranja FortGuard
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: _fontPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Filled Button
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: _fontPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: _primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: _fontPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: _fontPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      hintStyle: const TextStyle(fontFamily: _fontSecondary, color: _textMuted, fontSize: 15),
      labelStyle: const TextStyle(fontFamily: _fontSecondary, color: _textSecondary, fontSize: 15),
      floatingLabelStyle: const TextStyle(fontFamily: _fontPrimary, color: _primary, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIconColor: _textMuted,
      suffixIconColor: _textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _dividerColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _black,
      contentTextStyle: const TextStyle(fontFamily: _fontSecondary, color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Icons
    iconTheme: const IconThemeData(color: _textSecondary, size: 24),

    // FAB
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: _dividerColor, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return _dividerColor;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    // ListTile
    listTileTheme: const ListTileThemeData(
      iconColor: _textSecondary,
      textColor: _textPrimary,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    // Dialog
    dialogTheme: DialogTheme(
      backgroundColor: _surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: const TextStyle(fontFamily: _fontSecondary, color: _textSecondary, fontSize: 15),
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: _surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: _dividerColor,
      thickness: 1,
    ),

    // Popup Menu
    popupMenuTheme: PopupMenuThemeData(
      color: _surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _surface,
      selectedItemColor: _primary,
      unselectedItemColor: _textMuted,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontFamily: _fontPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: _fontSecondary, fontSize: 12),
    ),

    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surface,
      elevation: 0,
      indicatorColor: _primary.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _primary, size: 24);
        }
        return const IconThemeData(color: _textMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontFamily: _fontPrimary, color: _primary, fontSize: 12, fontWeight: FontWeight.w600);
        }
        return const TextStyle(fontFamily: _fontSecondary, color: _textMuted, fontSize: 12);
      }),
    ),

    // Tab Bar
    tabBarTheme: const TabBarTheme(
      labelColor: _primary,
      unselectedLabelColor: _textMuted,
      indicatorColor: _primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: _dividerColor,
      labelStyle: TextStyle(fontFamily: _fontPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: _fontSecondary, fontSize: 15, fontWeight: FontWeight.w400),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceSecondary,
      selectedColor: _primary.withValues(alpha: 0.15),
      labelStyle: const TextStyle(fontFamily: _fontSecondary, color: _textPrimary, fontSize: 14),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // Drawer
    drawerTheme: const DrawerThemeData(
      backgroundColor: _surface,
    ),

    // ═══════════════════════════════════════════════════════════
    // TEXT THEME - Brandbook hierarchy
    // Títulos: Poppins Bold (32-48pt)
    // Subtítulos: Poppins Regular (18-24pt)
    // Cuerpo: Lexend Deca Light (10-12pt)
    // ═══════════════════════════════════════════════════════════
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 48),
      displayMedium: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 40),
      displaySmall: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 32),
      headlineLarge: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 28),
      headlineMedium: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 24),
      headlineSmall: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
      titleLarge: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(fontFamily: _fontSecondary, color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: _fontSecondary, color: _textPrimary, fontWeight: FontWeight.w300, fontSize: 14),
      bodySmall: TextStyle(fontFamily: _fontSecondary, color: _textSecondary, fontWeight: FontWeight.w300, fontSize: 12),
      labelLarge: TextStyle(fontFamily: _fontPrimary, color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
      labelMedium: TextStyle(fontFamily: _fontSecondary, color: _textSecondary, fontWeight: FontWeight.w400, fontSize: 12),
      labelSmall: TextStyle(fontFamily: _fontSecondary, color: _textMuted, fontWeight: FontWeight.w300, fontSize: 11),
    ),
  );

  // Alias para compatibilidad
  static ThemeData get light => theme;
  static ThemeData get dark => theme;
}
