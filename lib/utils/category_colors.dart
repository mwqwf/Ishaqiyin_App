import 'package:flutter/material.dart';
import '../theme.dart';

/// Stable accent color per category id for visual differentiation.
Color colorForCategory(String id) {
  // درجات عميقة ومنخفضة التشبّع، وكلها تحقق تبايناً مناسباً مع النص الأبيض.
  // أبقينا تنوع الأقسام من دون الألوان الفاقعة أو الأخضر النيوني.
  const palette = [
    kTeal,
    kBlue,
    kGold,
    kGreen,
    kOrange,
    Color(0xFF685487), // بنفسجي تراثي هادئ
    Color(0xFF884A52), // عنّابي دافئ
    Color(0xFF2F6E70), // فيروزي عميق
  ];
  if (id.isEmpty) return kTeal;
  var hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash + c) % palette.length;
  }
  return palette[hash];
}

IconData iconForCategory(String id) {
  const icons = [
    Icons.menu_book,
    Icons.mosque,
    Icons.auto_stories,
    Icons.school,
    Icons.lightbulb,
    Icons.favorite,
    Icons.star,
    Icons.headphones,
  ];
  if (id.isEmpty) return Icons.folder;
  var hash = 0;
  for (final c in id.codeUnits) {
    hash = (hash + c) % icons.length;
  }
  return icons[hash];
}
