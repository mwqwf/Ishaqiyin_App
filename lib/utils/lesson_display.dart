import '../models.dart';

String formatDuration(Duration d) {
  if (d.inMilliseconds <= 0) return '';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String lessonDisplayTitle(Lesson l) {
  final t = l.title.trim();
  if (t.isNotEmpty && t.length > 3) return t;
  if (l.speaker.trim().isNotEmpty) return l.speaker.trim();
  return t.isNotEmpty ? t : 'درس صوتي';
}

String lessonShareLink(Lesson l, {int? startAtSeconds}) {
  final base = 'https://minbar-adkassahk.vercel.app/lesson/${l.id}';
  return startAtSeconds != null && startAtSeconds > 0
      ? '$base?t=$startAtSeconds'
      : base;
}

String lessonShareText(Lesson l,
    {String? categoryName, String? subName, int? startAtSeconds}) {
  final title = lessonDisplayTitle(l);
  final parts = <String>[title];
  if (subName != null && subName.isNotEmpty) parts.add('القسم: $subName');
  if (categoryName != null && categoryName.isNotEmpty) {
    parts.add('($categoryName)');
  }
  parts.add(lessonShareLink(l, startAtSeconds: startAtSeconds));
  return parts.join('\n');
}
