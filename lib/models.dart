import 'package:cloud_firestore/cloud_firestore.dart';

/// Some legacy documents are stored wrapped as `{ data: {...} }`.
Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
  final inner = raw['data'];
  if (inner is Map) {
    return Map<String, dynamic>.from(inner);
  }
  return raw;
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (v is Map && v['seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch((v['seconds'] as num).toInt() * 1000);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _str(dynamic v) => v == null ? '' : v.toString().trim();

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Picks the best available title from legacy field names.
String _extractTitle(Map<String, dynamic> d) {
  final title = _str(d['title']);
  if (title.isNotEmpty) return title;
  return _str(d['name']);
}

class Category {
  final String id;
  final String name;
  final DateTime createdAt;

  Category({required this.id, required this.name, required this.createdAt});

  factory Category.fromMap(String id, Map<String, dynamic> raw) {
    final d = _unwrap(raw);
    return Category(
      id: id,
      name: _str(d['name']),
      createdAt: _parseDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toCache() =>
      {'_id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};

  factory Category.fromCache(Map<String, dynamic> m) =>
      Category.fromMap(_str(m['_id']), m);
}

class Subcategory {
  final String id;
  final String name;
  final String categoryId;
  final DateTime createdAt;

  Subcategory({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.createdAt,
  });

  factory Subcategory.fromMap(String id, Map<String, dynamic> raw) {
    final d = _unwrap(raw);
    return Subcategory(
      id: id,
      name: _str(d['name']),
      categoryId: _str(d['categoryId']),
      createdAt: _parseDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toCache() => {
        '_id': id,
        'name': name,
        'categoryId': categoryId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subcategory.fromCache(Map<String, dynamic> m) =>
      Subcategory.fromMap(_str(m['_id']), m);
}

class Lesson {
  final String id;
  final String title;
  final String categoryId;
  final String subcategoryId;
  final String audioUrl;
  final DateTime createdAt;
  final int views;

  /// Optional metadata (may be absent in Firestore; duration also cached locally).
  final String speaker;
  final String description;
  final int durationMs;

  Lesson({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.subcategoryId,
    required this.audioUrl,
    required this.createdAt,
    this.views = 0,
    this.speaker = '',
    this.description = '',
    this.durationMs = 0,
  });

  static String _extractSubcategoryId(Map<String, dynamic> d) {
    if (d['subcategoryId'] != null && _str(d['subcategoryId']).isNotEmpty) {
      return _str(d['subcategoryId']);
    }
    final sub = d['subcategory'];
    if (sub is Map && sub['_id'] != null) return _str(sub['_id']);
    return '';
  }

  factory Lesson.fromMap(String id, Map<String, dynamic> raw) {
    final d = _unwrap(raw);
    return Lesson(
      id: id,
      title: _extractTitle(d),
      categoryId: _str(d['categoryId']),
      subcategoryId: _extractSubcategoryId(d),
      audioUrl: _str(d['audioUrl']),
      createdAt: _parseDate(d['createdAt']),
      views: _int(d['views']),
      speaker: _str(d['speaker'] ?? d['sheikh'] ?? d['reader']),
      description: _str(d['description']),
      durationMs: _int(d['durationMs'] ?? d['duration']),
    );
  }

  Map<String, dynamic> toCache() => {
        '_id': id,
        'title': title,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'audioUrl': audioUrl,
        'createdAt': createdAt.toIso8601String(),
        'views': views,
        'speaker': speaker,
        'description': description,
        'durationMs': durationMs,
      };

  factory Lesson.fromCache(Map<String, dynamic> m) =>
      Lesson.fromMap(_str(m['_id']), m);

  Lesson copyWith({int? durationMs, int? views}) => Lesson(
        id: id,
        title: title,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        audioUrl: audioUrl,
        createdAt: createdAt,
        views: views ?? this.views,
        speaker: speaker,
        description: description,
        durationMs: durationMs ?? this.durationMs,
      );
}

/// A user-created playlist of lessons (stored on-device only).
class Playlist {
  final String id;
  String name;
  List<String> lessonIds;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.lessonIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lessonIds': lessonIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> m) => Playlist(
        id: _str(m['id']),
        name: _str(m['name']),
        lessonIds: (m['lessonIds'] is List)
            ? (m['lessonIds'] as List).map((e) => e.toString()).toList()
            : <String>[],
        createdAt: _parseDate(m['createdAt']),
      );
}
