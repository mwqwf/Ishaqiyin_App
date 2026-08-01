import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import '../utils/lesson_display.dart';
import 'content_repository.dart';
import 'deep_link_service.dart';
import 'local_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // رسائل notification يعرضها النظام في الخلفية. data تُعالَج عند النقر.
}

/// الإشعارات المحلية والدفع مع جدولة حقيقية وفتح الدرس عند النقر.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final Set<int> _shownIds = <int>{};
  static bool _ready = false;
  static bool _pushReady = false;

  static const AndroidNotificationChannel _contentChannel =
      AndroidNotificationChannel(
    'content_updates',
    'محتوى جديد',
    description: 'إشعارات بإضافة دروس وأقسام وكتب جديدة',
    importance: Importance.high,
  );
  static const AndroidNotificationChannel _wardChannel =
      AndroidNotificationChannel(
    'daily_ward',
    'الوِرد اليومي',
    description: 'درس اليوم المقترح في الوقت الذي تختاره',
    importance: Importance.defaultImportance,
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        DeepLinkService.handleNotificationPayload(response.payload);
      },
    );
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_contentChannel);
    await androidImpl?.createNotificationChannel(_wardChannel);
    _ready = true;
  }

  static Future<void> initPush() async {
    if (_pushReady) return;
    _pushReady = true;
    try {
      final messaging = FirebaseMessaging.instance;
      if (LocalStore.getNotificationsEnabled()) {
        await messaging.requestPermission();
        await messaging.subscribeToTopic('content');
      } else {
        await messaging.unsubscribeFromTopic('content');
      }

      FirebaseMessaging.onMessage.listen((message) {
        if (!LocalStore.getNotificationsEnabled()) return;
        final n = message.notification;
        if (n == null) return;
        showContentNotification(
          n.title ?? 'منبر ادكصهك',
          n.body ?? '',
          payload: _payloadFor(message.data),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        DeepLinkService.handleNotificationData(message.data);
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        DeepLinkService.handleNotificationData(initial.data);
      }
    } catch (e) {
      _pushReady = false;
      debugPrint('initPush failed: $e');
    }
  }

  static String? _lessonId(Map<String, dynamic> data) {
    final id = (data['lessonId'] ?? data['lesson_id'] ?? data['id'] ?? '')
        .toString()
        .trim();
    return id.isEmpty ? null : id;
  }

  static String? _payloadFor(Map<String, dynamic> data) {
    if (data['type']?.toString() == 'submission') return 'submissions';
    final lessonId = _lessonId(data);
    return lessonId == null ? null : 'lesson:$lessonId';
  }

  /// المفتاح الرئيسي يوقف المحتوى والأقسام والجدولة المحلية معاً.
  static Future<void> setEnabled(bool enabled) async {
    final previous = LocalStore.getNotificationsEnabled();
    await LocalStore.setNotificationsEnabled(enabled);
    final messaging = FirebaseMessaging.instance;
    try {
      if (enabled) {
        await messaging.requestPermission();
        await requestPermission();
        await messaging.subscribeToTopic('content');
        await syncFollowedSubs();
        await rescheduleAll();
      } else {
        await messaging.unsubscribeFromTopic('content');
        for (final id in LocalStore.getFollowedSubs()) {
          if (id.isNotEmpty) {
            await messaging.unsubscribeFromTopic('sec_$id');
          }
        }
        await _cancelOwnedNotifications();
      }
    } catch (e) {
      await LocalStore.setNotificationsEnabled(previous);
      debugPrint('setEnabled failed: $e');
      rethrow;
    }
  }

  static Future<void> showContentNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    if (!_ready || !LocalStore.getNotificationsEnabled()) return;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1000000000);
    _shownIds.add(id);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _contentChannel.id,
        _contentChannel.name,
        channelDescription: _contentChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  static Future<void> requestPermission() async {
    if (!_ready) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static tz.TZDateTime _atLocalInstant(DateTime localDateTime) =>
      tz.TZDateTime.from(localDateTime.toUtc(), tz.UTC);

  static Future<void> scheduleContinueReminder() async {
    await _plugin.cancel(1);
    if (!_ready ||
        !LocalStore.getNotificationsEnabled() ||
        !LocalStore.getContinueReminderEnabled()) {
      return;
    }
    final completed = LocalStore.getCompletedIds().toSet();
    final positions = LocalStore.getPositions();
    String? lessonId;
    var maxPos = 0;
    positions.forEach((id, pos) {
      if (pos > maxPos && !completed.contains(id)) {
        maxPos = pos;
        lessonId = id;
      }
    });
    if (lessonId == null) return;
    final lesson = ContentRepository.instance.lessonById(lessonId!);
    if (lesson == null) return;

    final now = DateTime.now();
    var due = DateTime(now.year, now.month, now.day, 19);
    if (!due.isAfter(now.add(const Duration(hours: 2)))) {
      due = due.add(const Duration(days: 1));
    }
    const android = AndroidNotificationDetails(
      'continue_listening',
      'تابع الاستماع',
      channelDescription: 'تذكير لطيف بدرس لم تكمله',
      importance: Importance.defaultImportance,
    );
    await _plugin.zonedSchedule(
      1,
      'تابع الاستماع',
      'لديك درس لم تكمله بعد — ${lessonDisplayTitle(lesson)}',
      _atLocalInstant(due),
      const NotificationDetails(android: android),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'lesson:${lesson.id}',
    );
  }

  static Lesson? _wardForDate(List<Lesson> all, DateTime date) {
    final lessons = all.where((l) => l.audioUrl.isNotEmpty).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (lessons.isEmpty) return null;
    final seed = date.year * 1000 + date.month * 40 + date.day;
    return lessons[seed % lessons.length];
  }

  static Future<void> scheduleDailyWard() async {
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(700 + i);
    }
    if (!_ready ||
        !LocalStore.getNotificationsEnabled() ||
        !LocalStore.getWardEnabled()) {
      return;
    }
    final now = DateTime.now();
    for (var i = 0; i < 30; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final due = DateTime(day.year, day.month, day.day,
          LocalStore.getWardHour(), LocalStore.getWardMinute());
      if (!due.isAfter(now)) continue;
      final lesson = _wardForDate(ContentRepository.instance.lessons, day);
      if (lesson == null) continue;
      await _plugin.zonedSchedule(
        700 + i,
        'وِرد اليوم 🌿',
        lessonDisplayTitle(lesson),
        _atLocalInstant(due),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _wardChannel.id,
            _wardChannel.name,
            channelDescription: _wardChannel.description,
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'lesson:${lesson.id}',
      );
    }
  }

  /// اسم قديم أبقيناه للتوافق؛ أصبح يجدول الوِرد فعلياً حتى والتطبيق مغلق.
  static Future<void> maybeDeliverDailyWard() => scheduleDailyWard();

  static Future<void> rescheduleAll() async {
    await scheduleContinueReminder();
    await scheduleDailyWard();
  }

  static Future<void> _cancelOwnedNotifications() async {
    await _plugin.cancel(1);
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(700 + i);
    }
    for (final id in _shownIds) {
      await _plugin.cancel(id);
    }
    _shownIds.clear();
  }

  static Future<void> syncFollowedSubs() async {
    if (!LocalStore.getNotificationsEnabled()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      for (final id in LocalStore.getFollowedSubs()) {
        if (id.isNotEmpty) await messaging.subscribeToTopic('sec_$id');
      }
    } catch (e) {
      debugPrint('syncFollowedSubs failed: $e');
    }
  }

  static Future<void> subscribeSub(String subId) async {
    if (subId.isEmpty || !LocalStore.getNotificationsEnabled()) return;
    await FirebaseMessaging.instance.subscribeToTopic('sec_$subId');
  }

  static Future<void> unsubscribeSub(String subId) async {
    if (subId.isEmpty) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic('sec_$subId');
  }
}
