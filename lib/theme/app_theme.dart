import 'package:flutter/material.dart';

// Primary colors
const Color primaryColor = Color(0xFFE57171);
const Color sosButtonColorLight = Color(0xFFD05A5A);
const Color sosButtonColorDark = Color(0xFFC24A4A);

// Card backgrounds
const Color womenSafetyBgLight = Color(0xFFF7EBEF);
const Color womenSafetyBgDark = Color(0xFF2A1B1B);
const Color childSafetyBgLight = Color(0xFFDFF3FF);
const Color childSafetyBgDark = Color(0xFF1B2A3A);
const Color medicalBgLight = Color(0xFFE8FFF3);
const Color medicalBgDark = Color(0xFF1B2A25);
const Color legalBgLight = Color(0xFFFFF1DF);
const Color legalBgDark = Color(0xFF2A251B);

// Text
const Color textColorLight = Color(0xFF171212);
const Color textColorDark = Color(0xFFE0E0E0);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: primaryColor,
    onPrimary: Colors.white,
    surface: Colors.white,
    background: const Color(0xFFF8F6F6),
    onSurface: textColorLight,
    onBackground: textColorLight,
    error: Colors.red,
  ),
  textTheme: TextTheme(
    titleLarge: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textColorLight,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: textColorLight,
    ),
    bodyMedium: const TextStyle(fontSize: 14, color: Color(0xFF5C4A4A)),
    bodySmall: const TextStyle(fontSize: 12, color: Color(0xFF866565)),
  ),
  appBarTheme: AppBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: textColorLight,
    titleTextStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.015,
      color: textColorLight,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 2,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: primaryColor,
    onPrimary: Colors.white,
    surface: const Color(0xFF1E1B1B),
    background: const Color(0xFF121212),
    onSurface: textColorDark,
    onBackground: textColorDark,
    error: Colors.red,
  ),
  textTheme: TextTheme(
    titleLarge: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textColorDark,
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: textColorDark,
    ),
    bodyMedium: const TextStyle(fontSize: 14, color: Colors.grey),
    bodySmall: const TextStyle(fontSize: 12, color: Colors.grey),
  ),
  appBarTheme: AppBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: textColorDark,
    titleTextStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.015,
      color: textColorDark,
    ),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E1B1B),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 4,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF121212),
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey[400],
  ),
);
