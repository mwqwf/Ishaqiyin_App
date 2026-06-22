import 'package:flutter/material.dart';

// Brand palette carried over from the original app.
const kTeal = Color(0xFF247172);
const kSlate = Color(0xFF425563);
const kGold = Color(0xFFD4AF37);
const kBlue = Color(0xFF396AFC);
const kGreen = Color(0xFF38EF7D);
const kOrange = Color(0xFFFFA726);
const kPrimaryLight = Color(0xFF344955);
const kSecondary = Color(0xFFF9AA33);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kTeal,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? kSecondary : kPrimaryLight,
    secondary: kGold,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Amiri',
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF232B32) : const Color(0xFFF6FAFD),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF232B32) : kTeal,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontFamily: 'Amiri',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF1B2127) : Colors.white,
      selectedItemColor: kTeal,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontFamily: 'Amiri'),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Amiri'),
    ),
  );
}
