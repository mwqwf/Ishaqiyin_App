import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../theme.dart';
import 'lessons_screen.dart';
import 'player_screen.dart';
import 'subcategories_screen.dart';

/// مصدر الإشعارات المشترك (مجموعة notifications التي تكتبها Cloud Function).
/// يُخفي محلياً ما حذفه المستخدم.
class NotificationsFeed {
  static Stream<List<NotifItem>> stream({int limit = 50}) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('createdAtMs', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
      final dismissed = LocalStore.getDismissedNotifIds().toSet();
      return s.docs
          .map((d) => NotifItem.fromDoc(d.id, d.data()))
          .where((n) => !dismissed.contains(n.id))
          .toList();
    });
  }
}

class NotifItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String refId;
  final int createdAtMs;

  NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.refId,
    required this.createdAtMs,
  });

  factory NotifItem.fromDoc(String id, Map<String, dynamic> d) {
    var ms = 0;
    final raw = d['createdAtMs'] ?? d['createdAt'];
    if (raw is int) {
      ms = raw;
    } else if (raw is num) {
      ms = raw.toInt();
    } else if (raw is Timestamp) {
      ms = raw.millisecondsSinceEpoch;
    }
    return NotifItem(
      id: id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      type: (d['type'] ?? '').toString(),
      refId: (d['refId'] ?? '').toString(),
      createdAtMs: ms,
    );
  }
}

/// زر الجرس في الشريط العلوي — بنفس حجم زر البحث، مع عدّاد غير المقروء.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotifItem>>(
      stream: NotificationsFeed.stream(),
      builder: (context, snap) {
        final items = snap.data ?? const <NotifItem>[];
        final lastSeen = LocalStore.getLastSeenNotifMs();
        final unread = items.where((n) => n.createdAtMs > lastSeen).length;
        final bell = IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'الإشعارات',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
        if (unread <= 0) return bell;
        return Badge.count(count: unread, child: bell);
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // عند فتح القائمة تُعتبر كل الإشعارات مقروءة.
    LocalStore.setLastSeenNotifMs(DateTime.now().millisecondsSinceEpoch);
  }

  String _ago(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
    if (d.inHours < 24) return 'قبل ${d.inHours} س';
    return 'قبل ${d.inDays} ي';
  }

  IconData _icon(String type) {
    switch (type) {
      case 'lesson':
        return Icons.audiotrack;
      case 'category':
        return Icons.folder;
      case 'subcategory':
        return Icons.folder_open;
      case 'book':
        return Icons.menu_book;
      default:
        return Icons.campaign_outlined;
    }
  }

  /// الانتقال إلى العنصر المرتبط بالإشعار (نمط نبراس).
  void _openTarget(NotifItem n) {
    final repo = ContentRepository.instance;
    Widget? screen;
    switch (n.type) {
      case 'lesson':
        final l = repo.lessonById(n.refId);
        if (l != null) {
          final playlist = repo.lessons
              .where((x) => x.subcategoryId == l.subcategoryId)
              .toList();
          screen = PlayerScreen(
              lesson: l, playlist: playlist.isNotEmpty ? playlist : [l]);
        }
        break;
      case 'subcategory':
        final s = repo.subcategoryById(n.refId);
        if (s != null) screen = LessonsScreen(subcategory: s);
        break;
      case 'category':
        final c = repo.categoryById(n.refId);
        if (c != null) screen = SubcategoriesScreen(category: c);
        break;
    }
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العنصر غير متاح بعد — حدّث المحتوى.')),
      );
    }
  }

  Future<void> _dismiss(NotifItem n) async {
    await LocalStore.dismissNotif(n.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: StreamBuilder<List<NotifItem>>(
        stream: NotificationsFeed.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const <NotifItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد إشعارات بعد.',
                    style: TextStyle(fontSize: 17, color: Colors.grey)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _dismiss(n),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kTeal,
                    child: Icon(_icon(n.type), color: Colors.white, size: 20),
                  ),
                  title: Text(n.title.isNotEmpty ? n.title : 'إشعار',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: n.body.isNotEmpty ? Text(n.body) : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_ago(n.createdAtMs),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      IconButton(
                        tooltip: 'حذف',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                        onPressed: () => _dismiss(n),
                      ),
                    ],
                  ),
                  onTap: () => _openTarget(n),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
