import 'package:connectivity_plus/connectivity_plus.dart';
import '../models.dart';
import 'content_repository.dart';
import 'download_service.dart';
import 'firebase_repo.dart';
import 'local_store.dart';

/// Background auto-download when enabled in settings.
class AutoDownloadService {
  static Future<bool> _onWifi() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }

  static Future<void> runIfEnabled() async {
    if (!LocalStore.getAutoDownloadEnabled()) return;
    if (LocalStore.getAutoDownloadWifiOnly() && !await _onWifi()) return;

    final target = LocalStore.getAutoDownloadTarget() ?? 'recent';
    List<Lesson> lessons;
    if (target == 'main') {
      lessons = ContentRepository.instance.feed.take(30).toList();
    } else {
      lessons = await FirebaseRepo.fetchRecentLessons(limit: 30);
    }

    for (final l in lessons) {
      if (l.audioUrl.isEmpty) continue;
      if (DownloadService.isAudioDownloaded(l.id)) continue;
      try {
        await DownloadService.downloadAudio(l.id, l.audioUrl);
      } catch (_) {}
    }
  }
}
