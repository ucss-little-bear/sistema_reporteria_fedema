import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color buttonColor = Color(0xFF64748B);

  static const Color accentColor = Color(0xFF3B82F6);

  static const Color backgroundColor = Color(
    0xFFF8FAFC,
  );
  static const Color surfaceColor = Colors.white;


  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily:
          'Inter',

      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
      ),


      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation:
            0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            8,
          ),
          side: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),


      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),



      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),


      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),


      textTheme: TextTheme(
        headlineSmall: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleMedium: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.normal,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(color: Colors.grey.shade700),
      ),


      iconTheme: IconThemeData(color: Colors.grey.shade600),
    );
  }
}
