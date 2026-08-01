import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../services/submission_service.dart';
import '../theme.dart';
import 'lessons_screen.dart';
import 'player_screen.dart';
import 'subcategories_screen.dart';
import 'my_submissions_screen.dart';

/// مصدر الإشعارات المشترك (مجموعة notifications التي تكتبها Cloud Function)
/// مدموجاً مع قرارات «مساهماتي» المحسومة لمن لديه هوية مساهمات.
/// يُخفي محلياً ما حذفه المستخدم.
class NotificationsFeed {
  static Stream<List<NotifItem>> stream({int limit = 50}) {
    final db = FirebaseFirestore.instance;
    late StreamController<List<NotifItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? publicSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? privateSub;
    StreamSubscription<List<LessonSubmission>>? subsSub;
    StreamSubscription<User?>? authSub;
    var publicItems = <NotifItem>[];
    var privateItems = <NotifItem>[];
    var submissionItems = <NotifItem>[];

    void emit() {
      if (controller.isClosed) return;
      final dismissed = LocalStore.getDismissedNotifIds().toSet();
      final items = [...publicItems, ...privateItems, ...submissionItems]
          .where((n) => !dismissed.contains(n.id))
          .toList();
      items.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      controller.add(items.take(limit).toList());
    }

    controller = StreamController<List<NotifItem>>(
      onListen: () {
        publicSub = db
            .collection('notifications')
            .orderBy('createdAtMs', descending: true)
            .limit(limit)
            .snapshots()
            .listen((snap) {
          publicItems = snap.docs
              .map((d) => NotifItem.fromDoc('public:${d.id}', d.data()))
              .toList();
          emit();
        }, onError: controller.addError);

        authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
          unawaited(privateSub?.cancel());
          unawaited(subsSub?.cancel());
          privateItems = <NotifItem>[];
          submissionItems = <NotifItem>[];
          if (user == null) {
            emit();
            return;
          }
          privateSub = db
              .collection('user_notifications')
              .doc(user.uid)
              .collection('items')
              .orderBy('createdAtMs', descending: true)
              .limit(limit)
              .snapshots()
              .listen((snap) {
            privateItems = snap.docs
                .map((d) => NotifItem.fromDoc('private:${d.id}', d.data()))
                .toList();
            emit();
          }, onError: controller.addError);

          // قرارات مساهماتي المحسومة تظهر في الجرس كإشعارات اصطناعية.
          subsSub = SubmissionService.watchMine().listen((subs) {
            submissionItems = subs
                .where((s) => s.status != 'pending')
                .map(_decisionItem)
                .whereType<NotifItem>()
                .toList();
            emit();
          }, onError: (Object e) {
            // بث مساعد — خطؤه لا يُسقط قائمة الإشعارات الرئيسية.
            debugPrint('submissions feed error: $e');
          });
        }, onError: controller.addError);
      },
      onCancel: () async {
        await publicSub?.cancel();
        await privateSub?.cancel();
        await subsSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// يحوّل مساهمة محسومة إلى عنصر إشعار بنفس صياغات مراقب القرارات.
  static NotifItem? _decisionItem(LessonSubmission s) {
    String title;
    String body;
    switch (s.status) {
      case 'approved':
        title = 'نُشرت مساهمتك 🎉';
        body = 'وافق المشرفون على «${s.title}» ونُشرت كما هي. شكراً لمساهمتك!';
        break;
      case 'approved_edited':
        title = 'نُشرت مساهمتك بعد تعديل 🎉';
        body = 'نُشرت «${s.title}» بعد تحسينها من المشرفين. شكراً لمساهمتك!';
        break;
      case 'rejected':
        title = 'اعتذار عن نشر مساهمتك';
        body = s.rejectReason.isEmpty
            ? 'لم يوافق المشرفون على «${s.title}».'
            : 'لم تُنشر «${s.title}»: ${s.rejectReason}';
        break;
      default:
        return null;
    }
    return NotifItem(
      id: 'subdec_${s.id}',
      title: title,
      body: body,
      type: 'submission',
      refId: s.id,
      createdAtMs: s.decidedAtMs,
    );
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
    final d =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
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
      case 'submission':
        return Icons.how_to_vote;
      default:
        return Icons.campaign_outlined;
    }
  }

  /// الانتقال إلى العنصر المرتبط بالإشعار (نمط نبراس).
  void _openTarget(NotifItem n) {
    final repo = ContentRepository.instance;
    Widget? screen;
    switch (n.type) {
      case 'submission':
        screen = const MySubmissionsScreen();
        break;
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
