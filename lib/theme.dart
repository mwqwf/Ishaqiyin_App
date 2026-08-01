import 'package:flutter/material.dart';

// هوية «منبر»: تركواز عميق مع ذهبي معتّق ودرجات طبيعية مريحة للعين.
// الألوان الداكنة أدناه تحافظ على تباين واضح عند وضع النص الأبيض فوقها،
// وتتفادى الأخضر النيوني الذي كان يظهر في بعض الأقسام بحسب معرّف القسم.
const kTeal = Color(0xFF1E6668);
const kSlate = Color(0xFF334A57);
const kGold = Color(0xFF8A6724);
const kBlue = Color(0xFF416A8A);
const kGreen = Color(0xFF3E7661);
const kOrange = Color(0xFFA9602C);
const kPrimaryLight = kTeal;
const kSecondary = Color(0xFFD4B35C);

// درجتا إبراز مخصّصتان للأسطح الداكنة وبطاقات الأقسام.
const kPositiveOnDark = Color(0xFF9AD0B2);
const kGoldOnDark = Color(0xFFE0BD69);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kTeal,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? kSecondary : kPrimaryLight,
    secondary: kGold,
    surface: isDark ? const Color(0xFF1D2A30) : const Color(0xFFFBFCFA),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Amiri',
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF172328) : const Color(0xFFF6F8F5),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1B2B31) : kTeal,
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
      backgroundColor: isDark ? const Color(0xFF1B2B31) : Colors.white,
      selectedItemColor: isDark ? kSecondary : kTeal,
      unselectedItemColor:
          isDark ? const Color(0xFFA8B5B8) : const Color(0xFF6C7A80),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontFamily: 'Amiri'),
      unselectedLabelStyle: const TextStyle(fontFamily: 'Amiri'),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF1B2B31) : Colors.white,
      indicatorColor:
          isDark ? const Color(0xFF31575A) : const Color(0xFFDCEBE9),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
        fontFamily: 'Amiri',
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFE5ECEC) : kSlate,
      )),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? (isDark ? kSecondary : kTeal)
              : (isDark ? const Color(0xFFA8B5B8) : const Color(0xFF6C7A80)),
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: isDark ? kSecondary : kTeal,
      foregroundColor: isDark ? const Color(0xFF2C2411) : Colors.white,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: isDark ? kSecondary : kTeal,
      linearTrackColor:
          isDark ? const Color(0xFF33444B) : const Color(0xFFDDE5E3),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF34444A) : const Color(0xFFDDE4E2),
    ),
  );
}
