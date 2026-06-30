import 'package:flutter/material.dart';
import '../theme.dart';

/// Stable accent color per category id for visual differentiation.
Color colorForCategory(String id) {
  const palette = [
    kTeal,
    kBlue,
    kGold,
    kGreen,
    kOrange,
    Color(0xFF8E44AD),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
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
