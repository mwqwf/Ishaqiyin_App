import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'local_store.dart';

class DownloadService {
  static final Dio _dio = Dio();

  static Future<Directory> _dir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$sub');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  static String? localAudioPath(String lessonId) {
    final p = LocalStore.getAudioDownloads()[lessonId];
    if (p != null && File(p).existsSync()) return p;
    return null;
  }

  static bool isAudioDownloaded(String lessonId) =>
      localAudioPath(lessonId) != null;

  static List<MapEntry<String, String>> allDownloads() =>
      LocalStore.getAudioDownloads().entries.toList();

  static Future<void> deleteDownload(String lessonId) async {
    final path = localAudioPath(lessonId);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    await LocalStore.removeAudioDownload(lessonId);
  }

  static Future<String?> downloadAudio(
    String id,
    String url, {
    void Function(double percent)? onProgress,
  }) async {
    if (url.isEmpty) return null;
    final dir = await _dir('lessons');
    final cleaned = url.split('?').first;
    final ext = cleaned.contains('.') ? cleaned.split('.').last : 'mp3';
    final safeExt = (ext.isNotEmpty && ext.length <= 4) ? ext : 'mp3';
    final path = '${dir.path}/$id.$safeExt';
    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total * 100);
        }
      },
    );
    await LocalStore.setAudioDownload(id, path);
    await LocalStore.trackEvent('download');
    return path;
  }
}
