import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'content_repository.dart';
import '../screens/player_screen.dart';

/// Handles deep links like https://menbar.app/lesson/<id>
class DeepLinkService {
  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static GlobalKey<NavigatorState>? _navKey;

  static void init(GlobalKey<NavigatorState> navKey) {
    _navKey = navKey;
    _handleInitial();
    _sub = _links.uriLinkStream.listen(_handleUri);
  }

  static Future<void> _handleInitial() async {
    try {
      final uri = await _links.getInitialLink();
      if (uri != null) _handleUri(uri);
    } catch (_) {}
  }

  static void _handleUri(Uri uri) {
    final nav = _navKey?.currentState;
    if (nav == null) return;

    // /lesson/<id>
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'lesson') {
      final id = segments[1];
      _openLesson(nav.context, id);
    }
  }

  static void _openLesson(BuildContext context, String id) {
    final repo = ContentRepository.instance;
    final lesson = repo.lessonById(id);
    if (lesson == null) {
      repo.refresh(force: true).then((_) {
        final l = repo.lessonById(id);
        if (l != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(lesson: l, playlist: [l]),
            ),
          );
        }
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(lesson: lesson, playlist: [lesson]),
      ),
    );
  }

  static void dispose() {
    _sub?.cancel();
  }
}
