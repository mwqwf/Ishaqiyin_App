import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'content_repository.dart';
import '../screens/player_screen.dart';
import '../screens/my_submissions_screen.dart';

/// Handles deep links like https://minbar-adkassahk.vercel.app/lesson/<id>.
class DeepLinkService {
  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static GlobalKey<NavigatorState>? _navKey;
  static Uri? _pendingUri;
  static bool _drainScheduled = false;

  static void init(GlobalKey<NavigatorState> navKey) {
    _navKey = navKey;
    _handleInitial();
    _sub = _links.uriLinkStream.listen(_queueUri);
  }

  static Future<void> _handleInitial() async {
    try {
      final uri = await _links.getInitialLink();
      if (uri != null) _queueUri(uri);
    } catch (_) {}
  }

  static void _queueUri(Uri uri) {
    _pendingUri = uri;
    _scheduleDrain();
  }

  static void _scheduleDrain() {
    if (_drainScheduled || _pendingUri == null) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      final nav = _navKey?.currentState;
      final uri = _pendingUri;
      if (nav == null || uri == null) {
        if (_pendingUri != null) {
          Future<void>.delayed(
              const Duration(milliseconds: 150), _scheduleDrain);
        }
        return;
      }
      _pendingUri = null;
      _handleUri(nav, uri);
    });
  }

  static void _handleUri(NavigatorState nav, Uri uri) {
    // /lesson/<id>?t=<seconds>  (t = بداية «اللحظة» المشاركة)
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'lesson') {
      final id = segments[1];
      final tSec = int.tryParse(uri.queryParameters['t'] ?? '');
      _openLesson(nav.context, id, tSec == null ? null : tSec * 1000);
      return;
    }
    if (segments.isNotEmpty && segments[0] == 'my-submissions') {
      nav.push(
        MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
      );
    }
  }

  /// يربط بيانات FCM بالدرس سواء أرسل الخادم رابطاً أو معرّف درس.
  static void handleNotificationData(Map<String, dynamic> data) {
    if (data['type']?.toString() == 'submission') {
      _queueUri(Uri(
        scheme: 'https',
        host: 'minbar-adkassahk.vercel.app',
        pathSegments: const ['my-submissions'],
      ));
      return;
    }
    final rawLink = (data['link'] ?? data['url'] ?? '').toString().trim();
    if (rawLink.isNotEmpty) {
      final uri = Uri.tryParse(rawLink);
      if (uri != null) _queueUri(uri);
      return;
    }
    final id = (data['lessonId'] ?? data['lesson_id'] ?? data['id'] ?? '')
        .toString()
        .trim();
    if (id.isNotEmpty) {
      _queueUri(Uri(
        scheme: 'https',
        host: 'minbar-adkassahk.vercel.app',
        pathSegments: ['lesson', id],
      ));
    }
  }

  /// حمولة الإشعار المحلي: lesson:<id> أو رابط كامل.
  static void handleNotificationPayload(String? payload) {
    final value = payload?.trim() ?? '';
    if (value.isEmpty) return;
    if (value.startsWith('lesson:')) {
      final id = value.substring('lesson:'.length).trim();
      if (id.isNotEmpty) handleNotificationData({'lessonId': id});
      return;
    }
    if (value == 'submissions') {
      handleNotificationData({'type': 'submission'});
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri != null) _queueUri(uri);
  }

  static void _openLesson(BuildContext context, String id, [int? startAtMs]) {
    final repo = ContentRepository.instance;
    final lesson = repo.lessonById(id);
    if (lesson == null) {
      repo.refresh(force: true).then((_) {
        final l = repo.lessonById(id);
        if (l != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PlayerScreen(lesson: l, playlist: [l], startAtMs: startAtMs),
            ),
          );
        }
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
            lesson: lesson, playlist: [lesson], startAtMs: startAtMs),
      ),
    );
  }

  static void dispose() {
    _sub?.cancel();
  }
}
