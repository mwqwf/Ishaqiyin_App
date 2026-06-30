/// Arabic-aware search normalization: strips diacritics, unifies hamza/alif,
/// ta marbuta, and tatweel so "احمد" matches "أحمد".
String normalizeArabic(String input) {
  var s = input.trim().toLowerCase();
  // Remove tashkeel / diacritics
  s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
  // Tatweel
  s = s.replaceAll('\u0640', '');
  // Alef variants → bare alef
  s = s.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
  // Ya / alef maksura
  s = s.replaceAll('ى', 'ي');
  // Ta marbuta → ha (common search equivalence)
  s = s.replaceAll('ة', 'ه');
  // Waw with hamza
  s = s.replaceAll('ؤ', 'و');
  // Ya with hamza
  s = s.replaceAll('ئ', 'ي');
  return s;
}

bool arabicContains(String haystack, String needle) {
  if (needle.isEmpty) return true;
  return normalizeArabic(haystack).contains(normalizeArabic(needle));
}
