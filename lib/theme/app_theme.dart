import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF2563EB);

  static const Color secondaryBlue = Color(0xFF3B82F6);

  static const Color accentYellow = Color(0xFFFACC15);

  static const Color background = Color(0xFFF8FAFC);

  static const Color card = Colors.white;

  static const Color title = Color(0xFF0F172A);

  static const Color subtitle = Color(0xFF64748B);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ),

    fontFamily: "Roboto",

    cardColor: card,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: title,
    ),
  );
}