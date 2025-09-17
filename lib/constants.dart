import 'package:flutter/material.dart';

class AppConfig {
  static const String serverUrl = "https://0.0.0.0:8000";
  //static const String serverUrl = "http://192.168.0.106:8000";
// static const String serverUrl = "http://10.0.2.2:8000"; // для Android эмулятора
}

class AppColors {
  static const Color sapphire = Color(0xFF0F52BA);
  static const Color gold = Color(0xFFFFD700);
  static const Color white = Colors.white;
  static const Color gray = Color(0xFFB0B0B0);
  static const Color lightGray = Color(0xFFF1F1F1);

  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFFB0B0B0);
  static const Color textWhite = Color(0xFFFFFFFF);

  static const Color primary = sapphire;

  static const Color accent = Color(0xFFFFC107);
  static const Color background = Color(0xFF121212);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFF2A2A2A);

  static const Color secondary = Color(0xFFE53935);
  static const Color whiteBackground = Color(0xFF1E1E1E);

  static const Color buttonTextLight = Colors.white;
  static const Color buttonBackgroundDark = Color(0xFF3C3C3C);
  static const Color buttonBackgroundLight = Color(0xFF757575);
}