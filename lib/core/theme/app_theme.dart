import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Premium Custom Color Palette
  static const Color primaryGold = Color(0xFFD4B26F); // Champagne Gold
  static const Color primaryGoldDark = Color(0xFFB59353);
  static const Color primaryGoldLight = Color(0xFFF2E6D0);

  // Background colors
  static const Color bgLight = Color(0xFFFAF8F5); // Elegant Soft Cream
  static const Color bgDark = Color(0xFF0F111A); // Sleek Midnight Slate
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF161924);

  // Accent Colors
  static const Color successGreen = Color(0xFF2E7D32); // Emerald Green
  static const Color errorRed = Color(0xFFC62828); // Royal Crimson
  static const Color warningSaffron = Color(0xFFEF6C00); // Warm Saffron
  static const Color infoBlue = Color(0xFF1565C0); // Deep Royal Blue

  // Light Mode Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        onPrimary: Colors.black,
        secondary: Color(0xFF4A4E69),
        onSecondary: Colors.white,
        background: bgLight,
        onBackground: Color(0xFF1A1A1A),
        surface: cardLight,
        onSurface: Color(0xFF1A1A1A),
        error: errorRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      cardTheme: CardTheme(
        color: cardLight,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: GoogleFonts.montserrat(color: Colors.grey.shade600),
        floatingLabelStyle: GoogleFonts.montserrat(color: primaryGold),
      ),
    );
  }

  // Dark Mode Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        onPrimary: Colors.black,
        secondary: Color(0xFF9A8C98),
        onSecondary: Colors.black,
        background: bgDark,
        onBackground: Color(0xFFE2E4EB),
        surface: cardDark,
        onSurface: Color(0xFFE2E4EB),
        error: errorRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgDark,
      cardTheme: CardTheme(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: Color(0xFFE2E4EB),
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF1B1D2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: GoogleFonts.montserrat(color: Colors.grey.shade400),
        floatingLabelStyle: GoogleFonts.montserrat(color: primaryGold),
      ),
    );
  }

  // Premium Typography Setup
  static TextTheme _textTheme(Brightness brightness) {
    final baseColor = brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFFE2E4EB);
    
    return TextTheme(
      displayLarge: GoogleFonts.cinzel(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: baseColor,
        letterSpacing: 1.2,
      ),
      displayMedium: GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      titleLarge: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor.withOpacity(0.8),
      ),
      labelLarge: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: baseColor,
        letterSpacing: 1.0,
      ),
    );
  }
}
