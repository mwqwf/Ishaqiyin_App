import 'package:cloud_firestore/cloud_firestore.dart';

/// Some legacy documents are stored wrapped as `{ data: {...} }`.
/// Unwrap to the inner map when present (mirrors the old `extractData`).
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

  /// Global, anonymous, aggregate play counter (read from Firestore `views`).
  /// Used only to rank "most listened". Defaults to 0 when absent.
  final int views;

  Lesson({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.subcategoryId,
    required this.audioUrl,
    required this.createdAt,
    this.views = 0,
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
      title: _str(d['title']),
      categoryId: _str(d['categoryId']),
      subcategoryId: _extractSubcategoryId(d),
      audioUrl: _str(d['audioUrl']),
      createdAt: _parseDate(d['createdAt']),
      views: _int(d['views']),
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
      };

  factory Lesson.fromCache(Map<String, dynamic> m) =>
      Lesson.fromMap(_str(m['_id']), m);
}

class Book {
  final String id;
  final String name;
  final String author;
  final String pdfUrl;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.name,
    required this.author,
    required this.pdfUrl,
    required this.createdAt,
  });

  factory Book.fromMap(String id, Map<String, dynamic> raw) {
    final d = _unwrap(raw);
    return Book(
      id: id,
      name: _str(d['name']),
      author: _str(d['author']),
      pdfUrl: _str(d['pdfUrl']),
      createdAt: _parseDate(d['createdAt']),
    );
  }

  Map<String, dynamic> toCache() => {
        '_id': id,
        'name': name,
        'author': author,
        'pdfUrl': pdfUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Book.fromCache(Map<String, dynamic> m) =>
      Book.fromMap(_str(m['_id']), m);
}
