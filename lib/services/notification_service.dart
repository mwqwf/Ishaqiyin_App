import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'content_repository.dart';
import 'local_store.dart';

/// معالج رسائل FCM في الخلفية (يجب أن يكون دالة عُليا).
/// رسائل الإشعار تُعرَض تلقائياً من النظام في الخلفية؛ هذا للتسجيل فقط.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // لا حاجة لعمل شيء: حمولة notification تُعرَض تلقائياً على قناة content_updates.
}

/// إشعارات محلية (تابع الاستماع) + استقبال إشعارات الدفع (FCM) من لوحة الإدارة.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// قناة محتوى جديد — يجب أن يطابق معرّفها channelId في Cloud Function.
  static const AndroidNotificationChannel _contentChannel =
      AndroidNotificationChannel(
    'content_updates',
    'محتوى جديد',
    description: 'إشعارات بإضافة دروس وأقسام وكتب جديدة',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_contentChannel);
    _ready = true;
  }

  /// تهيئة الدفع: طلب الإذن + الاشتراك في موضوع المحتوى + عرض الرسائل الواردة.
  static Future<void> initPush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.subscribeToTopic('content');

      // المقدّمة: نعرض الإشعار يدوياً (لا يعرضه النظام تلقائياً).
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n != null) {
          showContentNotification(n.title ?? 'منبر ادكصهك', n.body ?? '');
        }
      });
    } catch (e) {
      debugPrint('initPush failed: $e');
    }
  }

  static Future<void> showContentNotification(String title, String body) async {
    if (!_ready) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _contentChannel.id,
        _contentChannel.name,
        channelDescription: _contentChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static Future<void> scheduleContinueReminder() async {
    if (!_ready || !LocalStore.getContinueReminderEnabled()) return;
    final positions = LocalStore.getPositions();
    if (positions.isEmpty) return;

    String? lessonId;
    int maxPos = 0;
    positions.forEach((id, pos) {
      if (pos > maxPos && !LocalStore.getCompletedIds().contains(id)) {
        maxPos = pos;
        lessonId = id;
      }
    });
    if (lessonId == null) return;

    final lesson = ContentRepository.instance.lessonById(lessonId!);
    if (lesson == null) return;

    const android = AndroidNotificationDetails(
      'continue_listening',
      'تابع الاستماع',
      channelDescription: 'تذكير بلطف بدرس لم تكمله',
      importance: Importance.defaultImportance,
    );
    await _plugin.show(
      1,
      'تابع الاستماع',
      'لديك درس لم تكمله بعد — ${lesson.title.isNotEmpty ? lesson.title : 'درس صوتي'}',
      const NotificationDetails(android: android),
    );
  }

  static Future<void> requestPermission() async {
    if (!_ready) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }
}
