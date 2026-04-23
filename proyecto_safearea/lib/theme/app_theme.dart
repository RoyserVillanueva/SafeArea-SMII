import 'package:flutter/material.dart';

class AppTheme {
  // Color primario de marca - Material Design 3
  static const Color primaryBrandColor = Color(0xFF4A69FF); // Color primario de marca
  
  // Colores principales generados desde el color de marca
  // Estos se generan automáticamente con ColorScheme.fromSeed en Material Design 3
  static const Color errorColor = Color(0xFFBA1A1A); // Error color de Material Design 3
  
  // Colores calculados para compatibilidad
  static Color get primaryColor => primaryBrandColor;
  static Color get secondaryColor => const Color(0xFF6B84FF); // Tonalidad secundaria
  static Color get tertiaryColor => const Color(0xFF8C9EFF); // Tonalidad terciaria
  static Color get successColor => const Color(0xFF00C853); // Success color
  static Color get warningColor => const Color(0xFFFFA000); // Warning color
  
  // Gradientes generados desde el color primario
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBrandColor, const Color(0xFF1E5CD9)],
  );
  
  static LinearGradient get secondaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, const Color(0xFF4A6FD6)],
  );
  
  static LinearGradient get successGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successColor, const Color(0xFF00A847)],
  );
  
  // Tema claro - Material Design 3 con Material You (Color Dinámico)
  // Usa ThemeData.from() como base y luego personaliza con copyWith()
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBrandColor,
      brightness: Brightness.light,
      // El ColorScheme.fromSeed genera automáticamente:
      // - primary, onPrimary, primaryContainer, onPrimaryContainer
      // - secondary, onSecondary, secondaryContainer, onSecondaryContainer
      // - tertiary, onTertiary, tertiaryContainer, onTertiaryContainer
      // - error, onError, errorContainer, onErrorContainer
      // - background, onBackground
      // - surface, onSurface, surfaceVariant, onSurfaceVariant
      // - outline, outlineVariant
      // - shadow, scrim
    );
    
    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
          // La fuente se aplicará si está configurada en fontFamily
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ).copyWith(
      // AppBar Theme - Material Design 3
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      
      // Card Theme - Material Design 3
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Input Decoration Theme - Material Design 3
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      
      // Divider Theme - Material Design 3
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ),
    );
  }
  
  // Tema oscuro - Material Design 3 con Material You (Color Dinámico)
  // Usa ThemeData.from() como base y luego personaliza con copyWith()
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBrandColor,
      brightness: Brightness.dark,
      // Genera automáticamente todos los colores para modo oscuro
    );
    
    return ThemeData.from(
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
          // La fuente se aplicará si está configurada en fontFamily
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ).copyWith(
      // AppBar Theme para modo oscuro
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      
      // Card Theme para modo oscuro
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Input Decoration Theme para modo oscuro
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Divider Theme para modo oscuro
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
      ),
      
      // Icon Theme para modo oscuro
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }
}

// Colores para diferentes tipos de reportes
class ReportColors {
  static const Color robo = Color(0xFFEF4444);
  static const Color incendio = Color(0xFFF59E0B);
  static const Color emergencia = Color(0xFF6366F1);
  static const Color accidente = Color(0xFF8B5CF6);
  static const Color otro = Color(0xFF6B7280);
  
  static Color getColorForType(String type) {
    switch (type) {
      case 'robo':
        return robo;
      case 'incendio':
        return incendio;
      case 'emergencia':
        return emergencia;
      case 'accidente':
        return accidente;
      default:
        return otro;
    }
  }
  
  static String getLabelForType(String type) {
    switch (type) {
      case 'robo':
        return 'Robo';
      case 'incendio':
        return 'Incendio';
      case 'emergencia':
        return 'Emergencia';
      case 'accidente':
        return 'Accidente';
      case 'otro':
        return 'Otro';
      default:
        return type;
    }
  }
}

